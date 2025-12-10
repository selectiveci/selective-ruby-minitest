require "tempfile"
require 'digest'
require "json"

module Selective
  module Ruby
    module Minitest
      class RunnerWrapper
        class TestManifestError < StandardError; end

        attr_reader :test_case_callback, :reporter, :test_ids, :targeted_test_ids, :minitest_args, :test_map
        attr_accessor :connection_lost

        FRAMEWORK = "minitest"
        DEFAULT_TEST_DIR = "test"

        def initialize(args, test_case_callback)
          @test_case_callback = test_case_callback

          @targeted_test_ids, @minitest_args, wrapper_config_hash = parse_args(args)
          Selective::Ruby::Minitest::Monkeypatches.apply(wrapper_config_hash)

          configure
        end

        def manifest
          raise_test_manifest_error("No test cases found") if test_ids.empty?

          ids = @targeted_test_ids.any? ? @targeted_test_ids : test_ids
          {
            "test_cases" => ids.map do |test_id|
              test = test_map[test_id]
              {
                id: test_id,
                file_path: test[:file_path],
                run_time: 0.0
              }
            end
          }
        end

        def run_test_cases(test_case_ids)
          test_case_ids.map do |test_id|
            klass, method_name = get_test_from_map(test_id)
            real_time = time { klass.run_one_method(klass, method_name, reporter) }
            foo = format_test_case(test_id, klass, method_name, real_time)
            test_case_callback.call(foo)
          end
        end

        def remove_test_case_result(test_case_id)
          file_path, method_name = test_case_id.split(":")

          result = summary_reporter.results.detect do |r|
            r.source_location.first.gsub(root_path, "") == file_path &&
              r.name == method_name
          end

          result.failures = []

          summary_reporter.results.delete(result)
        end

        def base_test_path
          "./#{default_test_glob.split("/").first}"
        end

        def exit_status
          failures.reject(&:skipped?).length.zero? ? 0 : 1
        end

        def finish
          ::Minitest.selective_postrun(reporter, minitest_args)

          # This usually happens in at_exit defined in autorun.
          ::Minitest.class_variable_get(:@@after_run).reverse_each(&:call)
        end

        def framework
          RunnerWrapper::FRAMEWORK
        end

        def framework_version
          ::Minitest::VERSION
        end

        def wrapper_version
          ::Minitest::VERSION
        end

        private

        def time(&block)
          Benchmark.measure(&block).real
        end

        def get_test_from_map(test_id)
          t = test_map[test_id]

          [t[:klass], t[:method_name]]

        rescue
          puts "Test not found in map: #{test_id}"
        end

        def summary_reporter
          reporter.reporters.grep(::Minitest::SummaryReporter).first || # Minitest with no 3rd party reporter gems
            reporter.reporters.first.send(:all_reporters)&.grep(::Minitest::Reporters::DefaultReporter)&.first # Minitest with minitest-reporters gem
        end

        def failures
          summary_reporter.results
        end

        def failure_for(klass, method_name)
          failures.last.then do |last_failure|
            return if last_failure.nil?
            return unless klass.to_s == last_failure.klass
            return unless last_failure.name == method_name

            last_failure
          end
        end

        def format_test_case(test_id, klass, method_name, time)
          failure = failure_for(klass, method_name)
          test = test_map[test_id]

          status = if failure.nil?
            "passed"
          else
            failure.skipped? ? "pending" : "failed"
          end

          result = {
            id: test_id,
            description: method_name,
            full_description: method_name,
            status: status,
            file_path: test[:file_path],
            line_number: test[:line_number].to_i,
            run_time: time
          }

          failure && result.merge!(
            failure_message_lines: failure.to_s.split("\n"),
            failure_formatted_backtrace: failure.failures&.first&.backtrace || []
          )

          result
        end

        def default_test_glob
          ENV["DEFAULT_TEST"] || "#{DEFAULT_TEST_DIR}/**/*_test.rb"
        end

        def list_tests(patterns)
          Rake::FileList[patterns.any? ? patterns : default_test_glob].then do |files|
            include_pattern = ENV["INCLUDE_PATTERN"]
            exclude_pattern = ENV["EXCLUDE_PATTERN"]

            files = files.select { |file| file.match?(include_pattern) } if include_pattern
            files = files.reject { |file| file.match?(exclude_pattern) } if exclude_pattern

            files
          end
        end

        def parse_args(args)
          flag_args, test_ids = args.partition do |arg|
            arg.start_with?("-")
          end

          supported_wrapper_args = %w[]
          wrapper_args, minitest_args = flag_args.partition do |arg|
            supported_wrapper_args.any? do |p|
              arg.start_with?(p)
            end
          end

          wrapper_config_hash = wrapper_args.each_with_object({}) do |arg, hash|
            key = arg.sub("--", "").tr("-", "_").to_sym
            hash[key] = true
          end

          [test_ids, minitest_args, wrapper_config_hash]
        end

        def normalize_path(path)
          Pathname.new(path).relative_path_from("./")
        end

        def raise_test_manifest_error(output)
          raise TestManifestError.new("Selective could not generate a test manifest. The output was:\n#{output}")
        end

        def root_path
          "#{Dir.pwd}/"
        end

        def configure
          targeted_test_paths = targeted_test_ids.map { |test_id| test_id.split(":").first }.uniq
          tests = targeted_test_paths.any? ? targeted_test_paths : list_tests([])
          $LOAD_PATH.unshift "./#{DEFAULT_TEST_DIR}"
          tests.to_a.each { |path| require File.expand_path(path) }

          @reporter = ::Minitest.selective_prerun(minitest_args)
          suites = ::Minitest::Runnable.runnables.shuffle

          @test_ids, @test_map, duplicate_test_ids = suites.each_with_object([[], {}, []]) do |klass, (test_ids, test_map, duplicate_test_ids)|
            klass.runnable_methods.map do |method_name|
              file_path, line_number = klass.instance_method(method_name).source_location
              file_path = file_path.gsub(root_path, "")
              digest = Digest::MD5.hexdigest("#{klass.name}##{method_name}")
              test_id = "#{file_path}:#{digest}"

              if test_map[test_id]
                duplicate_test_ids << "#{file_path}:#{line_number}"
              else
                test_ids << test_id
                test_map[test_id] = {klass: klass, method_name: method_name, file_path: file_path, line_number: line_number}
              end
            end
          end

          if duplicate_test_ids.any?
            puts("\e[33mDuplicate test ids found. Please ensure unique test class/method names are used to ensure all tests are run. \n#{duplicate_test_ids.join("\n")}\e[0m")
          end
        end
      end
    end
  end
end

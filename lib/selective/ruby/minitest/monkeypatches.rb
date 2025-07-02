module Selective
  module Ruby
    module Minitest
      module Monkeypatches
        module Minitest
          def autorun
            # Noop. Rails calls autorun from: lib/active_support/testing/autorun.rb
            # when rails/test_help is required in test helper (which is normal rails test setup)
          end

          # This is the first half of Minitest.run
          def selective_prerun(args = [])
            load_plugins unless args.delete("--no-plugins") || ENV["MT_NO_PLUGINS"]

            options = process_args args

            ::Minitest.seed = options[:seed]
            srand ::Minitest.seed

            reporter = ::Minitest::CompositeReporter.new
            reporter << ::Minitest::SummaryReporter.new(options[:io], options)
            reporter << ::Minitest::ProgressReporter.new(options[:io], options) unless options[:quiet]

            self.reporter = reporter # this makes it available to plugins
            init_plugins options.merge(report_name: ->(name) { "report-#{name}-#{SecureRandom.uuid}.xml" })
            self.reporter = nil # runnables shouldn't depend on the reporter, ever

            parallel_executor.start if parallel_executor.respond_to?(:start)
            reporter.start
            reporter
          end

          # This is the second half of ::Minitest.run
          def selective_postrun(reporter, args = [])
            options = process_args args

            parallel_executor.shutdown

            # might have been removed/replaced during init_plugins:
            summary = reporter.reporters.grep(::Minitest::SummaryReporter).first

            reporter.report

            return empty_run! options if summary && summary.count == 0
            reporter.passed?
          end
        end

        def self.apply(config)
          ::Minitest.singleton_class.prepend(Minitest)
        end
      end
    end
  end
end

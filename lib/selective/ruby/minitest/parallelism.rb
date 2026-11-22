# frozen_string_literal: true

module Selective
  module Ruby
    module Minitest
      # Selective runs each test itself, in the process that traces and times
      # it. Minitest's executors would hand the test to a thread or a forked
      # Rails worker and return at once, so they are replaced by one that runs
      # the work inline. The parallelism they were configured with becomes the
      # number of Selective workers instead.
      module Parallelism
        class InlineExecutor
          def start
          end

          def shutdown
          end

          def size
            1
          end

          def <<(work)
            klass, method_name, reporter = work
            reporter.prerecord(klass, method_name) if reporter.respond_to?(:prerecord)
            result = if ::Minitest.respond_to?(:run_one_method)
              ::Minitest.run_one_method(klass, method_name)
            else
              klass.new(method_name).run
            end
            reporter.record(result)
          end
        end

        class << self
          # Replaces the configured executor and returns `[count, source]` for
          # the parallelism it asked for, or nil.
          def take_over!
            executor = ::Minitest.parallel_executor
            ::Minitest.parallel_executor = InlineExecutor.new
            install_parallel_fork_hooks
            @requested = rails_workers(executor) || parallel_fork_workers
          end

          attr_reader :requested

          private

          # The same decision Rails makes in ParallelizeExecutor#start.
          def rails_workers(executor)
            return unless defined?(::ActiveSupport::Testing::ParallelizeExecutor)
            return unless executor.is_a?(::ActiveSupport::Testing::ParallelizeExecutor)

            size = executor.size.to_i
            return if size < 2
            return unless ENV["PARALLEL_WORKERS"] || tests_count > executor.threshold.to_i

            [size, "Rails parallelize"]
          end

          def parallel_fork_workers
            return unless ::Minitest.respond_to?(:parallel_fork_number)

            [::Minitest.parallel_fork_number, "minitest-parallel_fork"]
          end

          def install_parallel_fork_hooks
            return if @parallel_fork_hooks
            return unless ::Minitest.respond_to?(:run_after_parallel_fork_hook)
            return unless defined?(Selective::Ruby::Core::Workers) && Selective::Ruby::Core::Workers.respond_to?(:on_start)

            @parallel_fork_hooks = true
            Selective::Ruby::Core::Workers.before_launch { ::Minitest.run_before_parallel_fork_hook }
            Selective::Ruby::Core::Workers.on_start { |index| ::Minitest.run_after_parallel_fork_hook(index) }
          end

          def tests_count
            ::Minitest::Runnable.runnables.sum { |runnable| runnable.runnable_methods.size }
          end
        end
      end
    end
  end
end

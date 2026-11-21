# frozen_string_literal: true

RSpec.describe Selective::Ruby::Minitest::Parallelism do
  let(:callback_calls) { [] }
  let(:runner_wrapper) do
    dirty_dirty_unprivate_class(Selective::Ruby::Minitest::RunnerWrapper).new([], ->(test_case) { callback_calls << test_case })
  end

  def test_id(method_name)
    runner_wrapper.test_map.detect { |_id, t| t[:method_name] == method_name }.first
  end

  before do
    Selective::Ruby::Minitest::Monkeypatches.apply({})
  end

  after do
    Selective::Ruby::Core::Workers.reset! if defined?(Selective::Ruby::Core::Workers)
  end

  it "runs parallelize_me! tests in the calling process" do
    runner_wrapper.run_test_cases([test_id("test_parallel_failing"), test_id("test_parallel_passing")])

    expect(::Minitest.parallel_executor).to be_a(described_class::InlineExecutor)
    expect(callback_calls.map { |c| [c[:description], c[:status]] }).to eq([
      ["test_parallel_failing", "failed"],
      ["test_parallel_passing", "passed"]
    ])
    expect(callback_calls.map { |c| c[:run_time] }).to all(be >= 0.05)
  end

  it "traces parallelize_me! tests" do
    skip "native tracer unavailable" unless Selective::Ruby::Core::TestMap.available?

    Selective::Ruby::Core::TestMap.configure(record: true)
    runner_wrapper.run_test_cases([test_id("test_parallel_passing")])

    deps = Selective::Ruby::Core::TestMap.recorder.to_h.then { |m| m[:tests].first[:deps].map { |i| m[:files][i] } }
    expect(deps).to include("spec/fixtures/parallel_me_test.rb")
  ensure
    Selective::Ruby::Core::TestMap.reset!
  end

  it "asks for no workers when nothing configured parallelism" do
    runner_wrapper

    expect(runner_wrapper.default_workers).to be_nil
  end

  context "with Rails parallelize" do
    let(:executor_class) do
      Class.new do
        attr_reader :size, :threshold

        def initialize(size:, threshold:)
          @size = size
          @threshold = threshold
        end

        def start
          raise "Rails' executor must not start under Selective"
        end
      end
    end

    before { stub_const("ActiveSupport::Testing::ParallelizeExecutor", executor_class) }

    around do |example|
      saved = ENV.delete("PARALLEL_WORKERS")
      example.run
    ensure
      saved ? ENV["PARALLEL_WORKERS"] = saved : ENV.delete("PARALLEL_WORKERS")
    end

    it "takes its worker count" do
      ::Minitest.parallel_executor = executor_class.new(size: 4, threshold: 1)

      expect(runner_wrapper.default_workers).to eq([4, "Rails parallelize"])
    end

    it "stays in one process below Rails' threshold" do
      ::Minitest.parallel_executor = executor_class.new(size: 4, threshold: 10_000)

      expect(runner_wrapper.default_workers).to be_nil
    end

    it "starts workers below the threshold when PARALLEL_WORKERS is set, as Rails does" do
      ENV["PARALLEL_WORKERS"] = "3"
      ::Minitest.parallel_executor = executor_class.new(size: 3, threshold: 10_000)

      expect(runner_wrapper.default_workers).to eq([3, "Rails parallelize"])
    end

    it "stays in one process with one worker" do
      ::Minitest.parallel_executor = executor_class.new(size: 1, threshold: 1)

      expect(runner_wrapper.default_workers).to be_nil
    end
  end

  context "with minitest-parallel_fork" do
    before do
      allow(::Minitest).to receive(:parallel_fork_number).and_return(6)
      allow(::Minitest).to receive(:run_before_parallel_fork_hook)
      allow(::Minitest).to receive(:run_after_parallel_fork_hook)
      described_class.instance_variable_set(:@parallel_fork_hooks, nil)
    end

    it "takes its worker count and runs its hooks in the workers" do
      expect(runner_wrapper.default_workers).to eq([6, "minitest-parallel_fork"])
      skip "selective-ruby-core has no workers" unless defined?(Selective::Ruby::Core::Workers)

      Selective::Ruby::Core::Workers.run_hooks(:before_launch)
      Selective::Ruby::Core::Workers.run_hooks(:on_start, 2)

      expect(::Minitest).to have_received(:run_before_parallel_fork_hook)
      expect(::Minitest).to have_received(:run_after_parallel_fork_hook).with(2)
    end
  end
end

# frozen_string_literal: true

RSpec.describe Selective::Ruby::Minitest::RunnerWrapper do
  let(:callback_calls) { [] }
  let(:test_case_callback) { ->(test_case) { callback_calls << test_case } }
  let(:args) { [] }

  let(:runner_wrapper) do
    dirty_dirty_unprivate_class(described_class).new(args, test_case_callback)
  end

  before do
    Selective::Ruby::Minitest::Monkeypatches.apply({})
  end

  describe "#initialize" do
    it "stores the test_case_callback" do
      expect(runner_wrapper.test_case_callback).to eq(test_case_callback)
    end

    it "splits positional args into targeted_test_ids" do
      runner = dirty_dirty_unprivate_class(described_class).new(
        ["spec/fixtures/example_test.rb"], test_case_callback
      )
      expect(runner.targeted_test_ids).to eq(["spec/fixtures/example_test.rb"])
    end

    it "splits flag args into minitest_args" do
      # Skip configure — the prerun step consumes/mutates the array as
      # part of normal Minitest option parsing, so the post-init state
      # would no longer reflect what parse_args produced.
      klass = dirty_dirty_unprivate_class(described_class)
      allow_any_instance_of(klass).to receive(:configure)

      runner = klass.new(["--no-plugins", "test/foo_test.rb"], test_case_callback)

      expect(runner.minitest_args).to eq(["--no-plugins"])
      expect(runner.targeted_test_ids).to eq(["test/foo_test.rb"])
    end

    it "sets up a CompositeReporter" do
      expect(runner_wrapper.reporter).to be_a(::Minitest::CompositeReporter)
    end

    it "builds a non-empty test_map keyed by test_id" do
      expect(runner_wrapper.test_ids).not_to be_empty
      expect(runner_wrapper.test_map).to include(runner_wrapper.test_ids.first)
    end
  end

  describe "#manifest" do
    it "returns a hash with test_cases" do
      result = runner_wrapper.manifest

      expect(result.keys).to eq(["test_cases"])
      expect(result["test_cases"]).not_to be_empty
      expect(result["test_cases"].first).to include(:id, :file_path, :run_time)
    end

    context "when no test cases were discovered" do
      it "raises a TestManifestError" do
        runner_wrapper.instance_variable_set(:@test_ids, [])

        expect { runner_wrapper.manifest }.to raise_error(
          described_class::TestManifestError, /No test cases found/
        )
      end
    end

    context "when targeted_test_ids are provided" do
      it "limits the manifest to the targeted ids" do
        target_id = runner_wrapper.test_ids.first
        runner_wrapper.instance_variable_set(:@targeted_test_ids, [target_id])

        result = runner_wrapper.manifest

        expect(result["test_cases"].length).to eq(1)
        expect(result["test_cases"].first[:id]).to eq(target_id)
      end
    end
  end

  describe "#base_test_path" do
    it "returns the leading directory of the default test glob" do
      expect(runner_wrapper.base_test_path).to eq("./spec")
    end
  end

  describe "#framework" do
    it "is minitest" do
      expect(runner_wrapper.framework).to eq("minitest")
    end
  end

  describe "#framework_version" do
    it "returns the loaded Minitest VERSION" do
      expect(runner_wrapper.framework_version).to eq(::Minitest::VERSION)
    end
  end

  describe "#wrapper_version" do
    it "returns the Minitest VERSION" do
      expect(runner_wrapper.wrapper_version).to eq(::Minitest::VERSION)
    end
  end

  describe "#exit_status" do
    it "returns 0 when there are no failures" do
      expect(runner_wrapper.exit_status).to eq(0)
    end
  end

  describe "#run_test_cases" do
    it "runs the test and invokes the callback with a formatted result" do
      passing_id = runner_wrapper.test_map.detect { |_id, t| t[:method_name] == "test_passing" }&.first
      expect(passing_id).not_to be_nil

      runner_wrapper.run_test_cases([passing_id])

      expect(callback_calls.length).to eq(1)
      result = callback_calls.first
      expect(result).to include(
        id: passing_id,
        description: "test_passing",
        status: "passed"
      )
      expect(result[:run_time]).to be_a(Numeric)
    end

    it "marks skipped tests as pending" do
      skipped_id = runner_wrapper.test_map.detect { |_id, t| t[:method_name] == "test_skipped" }&.first
      expect(skipped_id).not_to be_nil

      runner_wrapper.run_test_cases([skipped_id])

      expect(callback_calls.last[:status]).to eq("pending")
    end
  end

  describe "#remove_test_case_result" do
    it "no-ops gracefully when the test_id is unknown" do
      expect { runner_wrapper.remove_test_case_result("unknown") }.not_to raise_error
    end
  end
end

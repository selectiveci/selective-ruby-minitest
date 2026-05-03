# frozen_string_literal: true

RSpec.describe Selective::Ruby::Minitest::Monkeypatches do
  describe ".apply" do
    it "prepends the wrapper module onto Minitest's singleton class" do
      described_class.apply({})

      expect(::Minitest.singleton_class.ancestors).to include(described_class::Minitest)
    end
  end

  describe "#autorun" do
    before { described_class.apply({}) }

    it "is a no-op so Rails' autorun doesn't take over" do
      expect { ::Minitest.autorun }.not_to raise_error
    end
  end

  describe "#selective_prerun" do
    before { described_class.apply({}) }

    it "returns a CompositeReporter ready for runs" do
      reporter = ::Minitest.selective_prerun([])

      expect(reporter).to be_a(::Minitest::CompositeReporter)
      expect(reporter.reporters).to include(an_instance_of(::Minitest::SummaryReporter))
    end
  end
end

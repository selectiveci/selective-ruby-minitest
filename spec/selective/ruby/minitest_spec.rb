# frozen_string_literal: true

RSpec.describe Selective::Ruby::Minitest do
  describe ".register" do
    it "registers the runner wrapper with selective-ruby-core" do
      expect(Selective::Ruby::Core).to receive(:register_runner)
        .with("minitest", Selective::Ruby::Minitest::RunnerWrapper)

      described_class.register
    end
  end

  it "exposes a VERSION constant" do
    expect(Selective::Ruby::Minitest::VERSION).to be_a(String)
  end

  it "defines an Error class" do
    expect(Selective::Ruby::Minitest::Error).to be < StandardError
  end
end

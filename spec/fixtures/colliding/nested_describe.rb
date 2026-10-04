# frozen_string_literal: true

require "minitest"
require "minitest/spec"

NESTED_DESCRIBE_ATTEMPTS = Hash.new(0)

describe "Widget" do
  describe "alpha" do
    it "works" do
      flunk "Widget::alpha failed"
    end
  end

  describe "beta" do
    it "works" do
      attempt = NESTED_DESCRIBE_ATTEMPTS["beta"] += 1
      flunk "Widget::beta failed attempt #{attempt}" if attempt == 1
    end
  end
end

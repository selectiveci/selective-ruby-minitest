# frozen_string_literal: true

require "minitest"
require "minitest/test"

SHARED_MODULE_ATTEMPTS = Hash.new(0)

module SharedModuleChecks
  def test_shared
    attempt = SHARED_MODULE_ATTEMPTS[self.class.name] += 1
    flunk "#{self.class.name} failed attempt #{attempt}" if self.class.failing_attempt?(attempt)
  end
end

class AlphaTest < Minitest::Test
  include SharedModuleChecks

  def self.failing_attempt?(_attempt)
    true
  end
end

class BetaTest < Minitest::Test
  include SharedModuleChecks

  def self.failing_attempt?(attempt)
    attempt == 1
  end
end

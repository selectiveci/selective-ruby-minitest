# frozen_string_literal: true

require "minitest"
require "minitest/test"

class ExampleTest < ::Minitest::Test
  def test_passing
    assert true
  end

  def test_also_passing
    assert_equal 2, 1 + 1
  end

  def test_skipped
    skip "skipping for fixture purposes"
  end
end

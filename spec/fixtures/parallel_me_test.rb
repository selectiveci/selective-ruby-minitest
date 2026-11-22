# frozen_string_literal: true

require "minitest"
require "minitest/test"

class ParallelMeTest < ::Minitest::Test
  parallelize_me!

  def test_parallel_passing
    sleep 0.05
    assert true
  end

  def test_parallel_failing
    sleep 0.05
    assert_equal 3, 1 + 1
  end
end

# frozen_string_literal: true

require "zeitwerk"
require "minitest"
require "rake/file_list"
require "benchmark"
require "#{__dir__}/selective/ruby/minitest/version"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.inflector.inflect("minitest" => "Minitest")
loader.ignore("#{__dir__}/selective-ruby-minitest.rb")
loader.ignore("#{__dir__}/selective/ruby/minitest/version.rb")
loader.setup

require "selective-ruby-core"

module Selective
  module Ruby
    module Minitest
      class Error < StandardError; end

      def self.register
        Selective::Ruby::Core.register_runner(
          "minitest", Selective::Ruby::Minitest::RunnerWrapper
        )
      end
    end
  end
end

Selective::Ruby::Minitest.register

# frozen_string_literal: true

require_relative "helper_methods"
require "selective-ruby-minitest"

# Point the runner wrapper's default test glob at our fixtures so that
# specs which exercise the full configure/manifest paths don't depend on
# the consumer project's `test/` directory.
ENV["DEFAULT_TEST"] ||= "spec/fixtures/**/*_test.rb"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

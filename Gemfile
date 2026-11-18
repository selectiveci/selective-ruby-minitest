# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in selective-ruby-rspec.gemspec
gemspec

gem "rake", "~> 13.0"

gem "standard", "~> 1.3"

gem "irb"

# Bundler on Ruby < 3.3 picks prism 2.x platform gems that require Ruby 3.3.
gem "prism", "< 2" if RUBY_VERSION < "3.3"

gem "appraisal", "~> 2.5"

gem "minitest", ENV.fetch("MINITEST_VERSION", "~> 5.0"), group: :test

gem "mutex_m", group: :test

gem "rspec", "~> 3.12", group: :test

gem "simplecov", require: false, group: :test

if Dir.exist?(selective_ruby_core_path = "../selective-ruby-core")
  gem "selective-ruby-core", path: selective_ruby_core_path
else
  gem "selective-ruby-core", git: "https://github.com/selectiveci/selective-ruby-core.git", branch: "main"
end

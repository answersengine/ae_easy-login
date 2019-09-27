$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'simplecov'
require 'simplecov-console'
SimpleCov.formatter = SimpleCov::Formatter::Console
SimpleCov.start

require 'minitest'
require 'minitest/spec'
require 'minitest/autorun'
require 'timecop'
require 'byebug'
require 'ae_easy/login'

# TODO: Create all automated tests. It was tested before within a couple
# scrapers so we do know it works but we still need to provide full test
# coverage.

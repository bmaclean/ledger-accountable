# frozen_string_literal: true

require 'minitest/autorun'
require 'rails'
require 'active_record'
require 'database_cleaner-active_record'
require_relative '../lib/ledger_accountable'

class ActiveSupport::TestCase
  # Helper method to assert differences in values
  def assert_difference(expression, difference)
    before = eval(expression)
    yield
    after = eval(expression)
    assert_equal(difference, after - before)
  end
end

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = Logger::WARN
ActiveRecord::Base.include_root_in_json = true

# in-memory SQLite DB for testing
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

class Minitest::Test
  # Hook before each test
  def setup
    DatabaseCleaner.start
  end

  # Hook after each test
  def teardown
    DatabaseCleaner.clean
  end
end

# module LedgerAccountable
#   # your code here
#   Rails.application.config do |config|
#   end
# end

Dir[File.join(__dir__, 'support/**/*.rb')].each { |f| require f }

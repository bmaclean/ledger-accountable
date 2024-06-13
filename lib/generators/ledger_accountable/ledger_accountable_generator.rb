require 'rails/generators'
require 'rails/generators/active_record'

class LedgerAccountableGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  source_root File.expand_path('templates', __dir__)

  def create_model_file
    template 'ledger_entry.rb', 'app/models/ledger_entry.rb'
  end

  def create_migration_file
    migration_template 'migration.rb', 'db/migrate/create_ledger_entries.rb'
  end

  def create_initializer_file
    template 'initializer.rb', 'config/initializers/ledger_accountable.rb'
  end

  private

  def self.next_migration_number(path)
    ActiveRecord::Generators::Base.next_migration_number(path)
  end
end
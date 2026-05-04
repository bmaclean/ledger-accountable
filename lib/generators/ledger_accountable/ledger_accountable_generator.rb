require 'rails/generators'
require 'rails/generators/active_record'

class LedgerAccountableGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  source_root File.expand_path('templates', __dir__)
  class_option :add_indexes, type: :boolean, default: false,
                            desc: 'Generate only an additive migration to add missing ledger_entries indexes'

  def create_model_file
    return if options[:add_indexes]

    template 'ledger_entry.rb', 'app/models/ledger_entry.rb'
  end

  def create_migration_file
    return if options[:add_indexes]

    migration_template 'migration.rb', 'db/migrate/create_ledger_entries.rb'
  end

  def create_add_indexes_migration_file
    return unless options[:add_indexes]

    migration_template 'add_indexes_migration.rb', 'db/migrate/add_indexes_to_ledger_entries.rb'
  end

  def create_initializer_file
    return if options[:add_indexes]

    template 'initializer.rb', 'config/initializers/ledger_accountable.rb'
  end

  def copy_localization_file
    return if options[:add_indexes]

    copy_file '../../../locale/en.yml', 'config/locales/ledger.en.yml'
  end

  private

  def self.next_migration_number(path)
    ActiveRecord::Generators::Base.next_migration_number(path)
  end
end

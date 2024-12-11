# frozen_string_literal: true

$:.push File.expand_path('lib', __dir__)
require 'ledger_accountable/version'

Gem::Specification.new do |spec|
  spec.name          = 'ledger_accountable'
  spec.version       = LedgerAccountable::VERSION
  spec.authors       = ['Brendan Maclean', 'Igniter Tickets']
  spec.email         = ['brendan.maclean@alumni.ubc.ca']
  spec.homepage      = 'https://github.com/bmaclean/ledger-accountable'

  spec.summary       = 'Ledger accounting for Rails models'
  spec.description   = 'LedgerAccountable is a gem for recording ledger entries to store an accounting history in your Rails models.'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/bmaclean/ledger-accountable'
  spec.metadata['changelog_uri'] = 'https://github.com/bmaclean/ledger-accountable/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'false' # rubocop:disable Gemspec/RequireMFA

  spec.files         = Dir['{app,config,lib}/**/*', 'CHANGELOG.md', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0.6'

  # Runtime dependencies
  spec.add_dependency 'activerecord', '>= 6.0.0', '< 8'
  spec.add_dependency 'activesupport', '>= 6.0.0', '< 8'

  # Development dependencies
  spec.add_development_dependency 'database_cleaner-active_record', '= 2.1.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'sqlite3', '= 1.6.9'
end

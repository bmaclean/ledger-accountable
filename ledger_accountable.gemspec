# frozen_string_literal: true

$:.push File.expand_path("../lib", __FILE__)
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
  spec.metadata['changelog_uri'] = 'https://github.com/bmaclean/ledger-accountable/CHANGELOG.md'

  spec.files         = Dir['{app,config,lib}/**/*', 'CHANGELOG.md', 'LICENSE', 'README.md']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6.5'

  spec.add_dependency 'activerecord', ">= 6.0.0", "< 7.1"

  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end

# LedgerAccountable

**_This gem is in prerelease stages, and should not yet be considered stable for production release._**

`LedgerAccountable` is a gem for recording ledger entries to store an accounting history in your Rails models.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'ledger_accountable'
```

Then execute:

```bash
$ bundle install
```

To create the requisite migrations and models, run:

```bash
$ rails generate ledger_accountable
```

## Usage

Include `LedgerAccountable` in any model to enable ledger accounting functionality.

```ruby
class YourModel < ApplicationRecord
  include LedgerAccountable

  track_ledger :ledger_owner, 
               amount: :total,
               type: :credit
end
```

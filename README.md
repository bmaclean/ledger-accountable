# LedgerAccountable

`LedgerAccountable` is a Rails model concern that adds ledger functionality to any model.

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

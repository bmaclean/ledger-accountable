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

### `LedgerAccountable::LedgerOwner`

Include **`LedgerAccountable::LedgerOwner`** in any model which maintains a ledger - that is, a model whose instances have a sum balance of debits and credits based on the values of Ledger Item associations.

```ruby
class Order < ActiveRecord::Base
  include LedgerAccountable::LedgerOwner

  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :destroy
end
```

This provides methods for tracking the ledger:

- **`balance`** - Net sum of all ledger entries
- **`credit_total`** - Sum of all credit entries (e.g., payments)
- **`debit_total`** - Sum of all debit entries (e.g., charges)

### `LedgerAccountable::LedgerItem`

Include `LedgerAccountable::LedgerItem` in any associated model of a `LedgerAccountable::LedgerOwner` to trigger ledger entries when:

- Instances of that model are associated to the Ledger Owner
- Instances of that model are unassociated from the Ledger Owner
- Associated instances of that model are changed
- Associated instances of that model are destroyed

```ruby
class OrderItem < ActiveRecord::Base
  include LedgerAccountable::LedgerItem

  belongs_to :order

  # Track ledger changes on order with the cost method and provide a net_amount
  # to dynamically compute net changes to its cost
  track_ledger :order,
               amount: :cost,
               net_amount: :net_cost_change,
               type: :debit

  def cost
    quantity * unit_price
  end

  private

  def net_cost_change
    cost - (quantity_was * unit_price_was)
  end
end

class Payment < ActiveRecord::Base
  include LedgerAccountable::LedgerItem

  belongs_to :order

  # Track ledger changes on order with the amount attribute and mark it as a credit
  track_ledger :order, amount: :amount, type: :credit
end

class Refund < ActiveRecord::Base
  include LedgerAccountable::LedgerItem

  belongs_to :order

  # Track ledger changes on order with the amount attribute and mark it as a debit
  track_ledger :order, amount: :amount, type: :debit
end
```

The track_ledger method accepts the following options:

- **`amount`**: Method or attribute that determines the ledger amount (required)
- **`type`**: :debit or :credit (defaults to :credit)
- **`net_amount`**: Method to calculate amount changes for updates (optional)
- **`ledger_attributes`**: Additional attributes that should trigger ledger entries when changed (optional)

### Ledger Entry Types

Ledger entries are automatically created in the following scenarios:

- **`:addition`** - When a new item is added to a ledger
- **`:deletion`** - When an item is removed from a ledger
- **`:modification`** - When an item's amount changes

When a LedgerItem changes owners, both a `deletion` entry for the old owner and an `addition` entry for the new owner are created in the same transaction

<!-- TODO: documentation for alternate object destruction libraries: callbacks to trigger ledger removal for objects that aren't destroyed -->

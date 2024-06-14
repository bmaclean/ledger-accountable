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
class Order < ApplicationRecord
  has_many :ledger_entries, as: :owner
  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :destroy
end

class OrderItem < ApplicationRecord
  include LedgerAccountable

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


class Payment < ApplicationRecord
  include LedgerAccountable

  belongs_to :order

  # Track ledger changes on order with the amount attribute and mark it as a credit
  track_ledger :order, amount: :amount, type: :credit
end
```

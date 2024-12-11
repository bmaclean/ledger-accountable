# frozen_string_literal: true

require 'active_record'
require_relative '../../lib/generators/ledger_accountable/templates/ledger_entry'

ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.timestamps
  end

  create_table :order_items, force: true do |t|
    t.references :order, foreign_key: true
    t.integer :quantity
    t.integer :unit_price
    t.timestamps
  end

  create_table :payments, force: true do |t|
    t.references :order, foreign_key: true
    t.integer :amount
    t.timestamps
  end

  create_table :refunds, force: true do |t|
    t.references :order, foreign_key: true
    t.integer :amount
    t.timestamps
  end

  create_table :ledger_entries do |t|
    t.references :owner, polymorphic: true, null: false
    t.references :ledger_item, polymorphic: true, type: :string, null: false
    t.integer :transaction_type, null: false
    t.integer :entry_type, null: false
    t.integer :amount_cents, default: 0, null: false
    t.text :metadata

    t.timestamps
  end
end

class Order < ActiveRecord::Base
  has_many :ledger_entries, as: :owner
  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :destroy

  def balance
    ledger_entries.sum(:amount_cents)
  end
end

class OrderItem < ActiveRecord::Base
  include LedgerAccountable::LedgerItem

  belongs_to :order

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

  track_ledger :order, amount: :amount, type: :credit
end

class Refund < ActiveRecord::Base
  include LedgerAccountable::LedgerItem

  belongs_to :order

  track_ledger :order, amount: :amount, type: :debit
end

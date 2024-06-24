require 'test_helper'

class LedgerAccountableTest < ActiveSupport::TestCase
  test 'creates a ledger entry when an order item is added' do
    order = Order.create!
    order_item = OrderItem.new(order: order, quantity: 3, unit_price: 10)

    assert_difference 'LedgerEntry.count', 1 do
      order_item.save!
    end
  end

  test 'creates a ledger entry when a payment is added' do
    order = Order.create!
    payment = Payment.new(order: order, amount: 30)

    assert_difference 'LedgerEntry.count', 1 do
      payment.save!
    end
  end

  test 'creates a deletion ledger entry when an order item is destroyed' do
    order = Order.create!
    order_item = OrderItem.create!(order: order, quantity: 3, unit_price: 10)

    assert_difference 'LedgerEntry.count', 1 do
      order_item.destroy
    end

    last_entry = LedgerEntry.last
    assert_equal 'deletion', last_entry.entry_type
    # entry amount should be positive, as a debit was removed
    assert_equal(order_item.cost, last_entry.amount_cents)
  end

  test 'creates a deletion ledger entry when a payment is destroyed' do
    order = Order.create!
    payment = Payment.create!(order: order, amount: 30)

    assert_difference 'LedgerEntry.count', 1 do
      payment.destroy
    end

    last_entry = LedgerEntry.last
    assert_equal 'deletion', last_entry.entry_type
    # entry amount should be negative, as a credit was removed
    assert_equal(-payment.amount, last_entry.amount_cents)
  end

  test 'creates a modification ledger entry when a debit ledger item is updated' do
    order = Order.create!
    refund = Refund.create!(order: order, amount: 10_00)
    previous_amount = refund.amount

    assert_difference 'LedgerEntry.count', 1 do
      refund.update(amount: 15_00)
    end

    last_entry = LedgerEntry.last
    assert_equal 'modification', last_entry.entry_type
    assert_equal(refund.amount - previous_amount, -last_entry.amount_cents)
  end

  test 'does not a modification ledger entry when a debit ledger item is updated, but the net amount remains the same' do
    order = Order.create!
    refund = Refund.create!(order: order, amount: 10_00)

    assert_difference 'LedgerEntry.count', 0 do
      refund.update(updated_at: 1.day.ago)
    end
  end

  test 'creates a modification ledger entry when a computed debit ledger item is updated' do
    order = Order.create!
    order_item = OrderItem.create!(order: order, quantity: 3, unit_price: 10)
    previous_cost = order_item.cost

    assert_difference 'LedgerEntry.count', 1 do
      order_item.update(quantity: 5, unit_price: 25)
    end

    last_entry = LedgerEntry.last
    assert_equal 'modification', last_entry.entry_type
    assert_equal(order_item.cost - previous_cost, -last_entry.amount_cents)
  end

  test 'does not a modification ledger entry when a computed debit ledger item is updated, but the net amount remains the same' do
    order = Order.create!
    order_item = OrderItem.create!(order: order, quantity: 3, unit_price: 10)

    assert_difference 'LedgerEntry.count', 0 do
      order_item.update(updated_at: 1.day.ago)
    end
  end

  test 'creates a modification ledger entry when a credit ledger item is updated' do
    order = Order.create!
    payment = Payment.create!(order: order, amount: 30)
    previous_amount = payment.amount

    assert_difference 'LedgerEntry.count', 1 do
      payment.update(amount: 40)
    end

    last_entry = LedgerEntry.last
    assert_equal 'modification', last_entry.entry_type
    assert_equal(payment.amount - previous_amount, last_entry.amount_cents)
  end

  test 'does not a modification ledger entry when a credit ledger item is updated, but the net amount remains the same' do
    order = Order.create!
    payment = Payment.create!(order: order, amount: 30)

    assert_difference 'LedgerEntry.count', 0 do
      payment.update(updated_at: 3.days.from_now)
    end
  end

  test 'raises an error if ledger owner is not specified' do
    class MyModel < ActiveRecord::Base
      include LedgerAccountable
    end
    err = assert_raises(RuntimeError) do
      MyModel.track_ledger(nil)
    end

    assert_equal 'LedgerAccountable model LedgerAccountableTest::MyModel must respond to the provided value for ledger_owner ().', err.message
  end

  test 'raises an error if ledger amount attribute is not specified' do
    class MyModel < ActiveRecord::Base
      include LedgerAccountable

      belongs_to :order
    end

    err = assert_raises(RuntimeError) do
      MyModel.track_ledger(:order)
    end

    assert_equal 'track_ledger :amount is required in LedgerAccountableTest::MyModel', err.message
  end

  test 'defaults transaction_type to credit if not specified' do
    assert_equal :credit, Payment.transaction_type
  end
end

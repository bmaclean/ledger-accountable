# frozen_string_literal: true

require 'test_helper'

class LedgerOwnerTest < ActiveSupport::TestCase
  def setup
    @order = Order.create!

    # Create some test entries with complete objects
    OrderItem.create!(
      order: @order,
      quantity: 2,
      unit_price: 500  # Will result in cost of 1000
    )
    Payment.create!(
      order: @order,
      amount: 800
    )
    OrderItem.create!(
      order: @order,
      quantity: 1,
      unit_price: 500  # Will result in cost of 500
    )
    Payment.create!(
      order: @order,
      amount: 400
    )
  end

  test 'includes ledger_entries association' do
    assert_respond_to @order, :ledger_entries
    assert_equal 4, @order.ledger_entries.reload.count
  end

  test 'calculates correct balance' do
    # -1000 + 800 + -500 + 400 = -300
    assert_equal(-300, @order.balance)
  end

  test 'calculates correct credit_total' do
    # |800 + 400| = 1200
    assert_equal 1200, @order.credit_total
  end

  test 'calculates correct debit_total' do
    # |-1000 + -500| = 1500
    assert_equal 1500,
                 @order.debit_total,
                 'debit_total appears to be using credits instead of debits'
  end

  test 'handles empty ledger' do
    new_order = Order.create!
    assert_equal 0, new_order.balance
    assert_equal 0, new_order.credit_total
    assert_equal 0, new_order.debit_total
  end

  test 'handles ledger with only credits' do
    order_with_credits = Order.create!
    Payment.create!(
      order: order_with_credits,
      amount: 1000
    )
    assert_equal 1000, order_with_credits.balance
    assert_equal 1000, order_with_credits.credit_total
    assert_equal 0, order_with_credits.debit_total
  end

  test 'handles ledger with only debits' do
    order_with_debits = Order.create!
    OrderItem.create!(
      order: order_with_debits,
      quantity: 2,
      unit_price: 500
    )

    assert_equal(-1000, order_with_debits.balance)
    assert_equal 0, order_with_debits.credit_total
    assert_equal 1000, order_with_debits.debit_total
  end

  test 'handles deletion entries in totals' do
    # Create and then delete a credit entry
    order = Order.create!
    payment = Payment.create!(
      order: order,
      amount: 1000
    )
    payment.destroy!

    assert_equal 0, order.balance
    assert_equal 0,
                 order.credit_total,
                 'credit_total should consider deletion entries'
    assert_equal 0, order.debit_total
  end
end

# frozen_string_literal: true

require 'test_helper'

class LedgerItemTest < ActiveSupport::TestCase
  def setup
    super
    @order = Order.create!
    @order2 = Order.create!
  end

  class ValidationTests < LedgerItemTest
    test 'defaults transaction_type to credit if not specified' do
      assert_equal :credit, Payment.transaction_type
    end

    test 'raises an error if ledger owner is not specified' do
      class MyModel < ActiveRecord::Base
        include LedgerAccountable::LedgerItem
      end
      assert_raises(LedgerAccountable::LedgerItem::InvalidLedgerOwnerError) do
        MyModel.track_ledger(nil)
      end
    end

    test 'raises error when ledger_amount_attribute method is not implemented' do
      class InvalidModel < ActiveRecord::Base
        include LedgerAccountable::LedgerItem

        # Set up an in-memory table for testing
        connection.create_table :invalid_models, force: true do |t|
          t.string :order_id
        end

        belongs_to :order
        track_ledger :order, amount: :nonexistent_method
      end

      assert_raises(NotImplementedError) do
        InvalidModel.create!(order: @order)
      end
    end

    test 'validates transaction type is either debit or credit' do
      err = assert_raises(RuntimeError) do
        class InvalidTypeModel < ActiveRecord::Base
          include LedgerAccountable::LedgerItem
          belongs_to :order
          track_ledger :order, amount: :amount, type: :invalid
        end
      end

      assert_match(/LedgerAccountable type must be :debit or :credit/, err.message)
    end

    test 'validates ledger attributes are symbols' do
      err = assert_raises(RuntimeError) do
        class InvalidAttributesModel < ActiveRecord::Base
          include LedgerAccountable::LedgerItem
          belongs_to :order
          track_ledger :order, amount: :amount, ledger_attributes: ['string']
        end
      end

      assert_match(/LedgerAccountable attributes must be symbols/, err.message)
    end
  end

  class CreationTests < LedgerItemTest
    test 'creates ledger entry with zero amount' do
      payment = Payment.new(order: @order, amount: 0)

      assert_difference 'LedgerEntry.count', 1 do
        payment.save!
      end

      entry = LedgerEntry.last
      assert_equal 0, entry.amount_cents
      assert_equal 'addition', entry.entry_type
    end

    test 'creates ledger entry with negative amount for debits' do
      OrderItem.create!(order: @order, quantity: 1, unit_price: 10)
      entry = LedgerEntry.last

      assert_equal(-10, entry.amount_cents)
      assert_equal 'debit', entry.transaction_type
    end

    test 'creates ledger entry with positive amount for credits' do
      Payment.create!(order: @order, amount: 10)
      entry = LedgerEntry.last

      assert_equal 10, entry.amount_cents
      assert_equal 'credit', entry.transaction_type
    end

    test 'handles fractional amounts correctly' do
      Payment.create!(order: @order, amount: 10.5)
      entry = LedgerEntry.last

      assert_equal 10, entry.amount_cents
    end

    test 'handles nil amounts gracefully' do
      payment = Payment.new(order: @order, amount: nil)

      assert_difference 'LedgerEntry.count', 1 do
        payment.save!
      end

      entry = LedgerEntry.last
      assert_equal 0, entry.amount_cents
    end
  end

  class UpdateTests < LedgerItemTest
    test 'creates modification entry only when amount changes' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 0 do
        payment.update!(updated_at: Time.current)
      end

      assert_difference 'LedgerEntry.count', 1 do
        payment.update!(amount: 20)
      end
    end

    test 'handles multiple updates correctly' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 2 do
        payment.update!(amount: 20)
        payment.update!(amount: 15)
      end

      modifications = LedgerEntry.where(entry_type: 'modification')
      assert_equal [10, -5], modifications.pluck(:amount_cents)
    end

    test 'correctly calculates net amount for computed values' do
      order_item = OrderItem.create!(order: @order, quantity: 2, unit_price: 10)

      assert_difference 'LedgerEntry.count', 1 do
        order_item.update!(quantity: 3, unit_price: 15)
      end

      modification = LedgerEntry.last
      assert_equal(-25, modification.amount_cents) # (3*15) - (2*10) = 45 - 20 = 25
    end

    test 'handles sequential updates to amount' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 3 do
        payment.update!(amount: 20)
        payment.update!(amount: 30)
        payment.update!(amount: 40)
      end

      modifications = LedgerEntry.where(entry_type: 'modification')
      assert_equal [10, 10, 10], modifications.pluck(:amount_cents)
    end
  end

  class OwnerTransitionTests < LedgerItemTest
    test 'creates appropriate entries when changing owners' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 2 do
        payment.update!(order: @order2)
      end

      entries = LedgerEntry.last(2)
      assert_equal 'deletion', entries.first.entry_type
      assert_equal 'addition', entries.last.entry_type
      assert_equal @order, entries.first.owner
      assert_equal @order2, entries.last.owner
    end

    test 'handles removal of owner correctly' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 1 do
        payment.update!(order: nil)
      end

      deletion = LedgerEntry.last
      assert_equal 'deletion', deletion.entry_type
      assert_equal(-10, deletion.amount_cents)
    end

    test 'handles addition of owner when no owner was present' do
      payment = Payment.create!(order: nil, amount: 10)

      assert_difference 'LedgerEntry.count', 1 do
        payment.update!(order: @order)
      end

      addition = LedgerEntry.last
      assert_equal 'addition', addition.entry_type
      assert_equal 10, addition.amount_cents
    end

    test 'handles circular owner changes' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 4 do
        payment.update!(order: @order2)
        payment.update!(order: @order)
      end

      entry_types = LedgerEntry.order(:created_at).pluck(:entry_type)
      # 1. :addition - original creation
      # 2. :deletion - remove from original order ledger
      # 3. :addition - add to order2 ledger
      # 4. :deletion - remove from order2 ledger
      # 5. :addition - add back to original order ledger
      assert_equal %w[addition deletion addition deletion addition], entry_types
    end
  end

  class DestructionTests < LedgerItemTest
    test 'creates correct deletion entry for credit items' do
      payment = Payment.create!(order: @order, amount: 10)

      assert_difference 'LedgerEntry.count', 1 do
        payment.destroy
      end

      deletion = LedgerEntry.last
      assert_equal 'deletion', deletion.entry_type
      assert_equal(-10, deletion.amount_cents)
    end

    test 'creates correct deletion entry for debit items' do
      order_item = OrderItem.create!(order: @order, quantity: 2, unit_price: 10)

      assert_difference 'LedgerEntry.count', 1 do
        order_item.destroy
      end

      deletion = LedgerEntry.last
      assert_equal 'deletion', deletion.entry_type
      assert_equal 20, deletion.amount_cents
    end

    test 'handles destruction of item with no owner' do
      payment = Payment.create!(order: nil, amount: 10)

      assert_difference 'LedgerEntry.count', 0 do
        payment.destroy
      end
    end
  end

  class MetadataTests < LedgerItemTest
    class MetadataPayment < Payment
      def build_ledger_metadata
        {
          user_id: 1,
          payment_method: 'credit_card',
          timestamp: Time.current.to_i
        }
      end
    end

    test 'stores metadata correctly' do
      MetadataPayment.create!(order: @order, amount: 10)
      entry = LedgerEntry.last

      assert_not_nil entry.metadata
      assert_equal 1, entry.metadata['user_id']
      assert_equal 'credit_card', entry.metadata['payment_method']
      assert_kind_of Integer, entry.metadata['timestamp']
    end

    test 'preserves metadata through modifications' do
      payment = MetadataPayment.create!(order: @order, amount: 10)
      payment.update!(amount: 20)

      entries = LedgerEntry.last(2)
      assert_equal entries[0].metadata, entries[1].metadata
    end
  end
end

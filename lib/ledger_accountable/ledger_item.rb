# frozen_string_literal: true

# LedgerAccountable::LedgerItem adds ledger functionality to any model that acts as an item in a ledger.
#
# It supports tracking two types of ledger entries:
# 1. Debits: outgoing items which decrease the ledger balance (for example, an item being sold)
# 2. Credits: incoming items which increase the ledger balance (for example, a payment taken)
#
# Usage:
# Include LedgerAccountable in a model to have it generate ledger entries based on its
# addition/deletion/update events relative to its ledger owner.
#
# Specify `ledger_owner`, the owner of the ledger entries, and optionally `ledger_attributes`
# to track specific attributes changes.
#
# Example:
# ```ruby
# class Order < ApplicationRecord
#   has_many :ledger_entries, as: :owner
#   has_many :order_items, dependent: :destroy
#   has_many :payments, dependent: :destroy
# end
#
# class OrderItem < ApplicationRecord
#   include LedgerAccountable::LedgerItem
#
#   belongs_to :order
#
#   # Track ledger changes on order with the cost method and provide a net_amount
#   # to dynamically compute net changes to its cost
#   track_ledger :order,
#                amount: :cost,
#                net_amount: :net_cost_change,
#                type: :debit
#   def cost
#     quantity * unit_price
#   end
#
#   private
#
#   def net_cost_change
#     cost - (quantity_was * unit_price_was)
#   end
# end
#
#
# class Payment < ApplicationRecord
#   include LedgerAccountable::LedgerItem
#
#   belongs_to :order
#
#   # Track ledger changes on order with the amount attribute and mark it as a credit
#   track_ledger :order, amount: :amount, type: :credit
# end
# ```
#
# Note:
#  - The `ledger_owner` association must exist in the LedgerAccountable::LedgerItem model.
#
module LedgerAccountable
  module LedgerItem
    autoload :EntryCreator, 'ledger_accountable/ledger_item/entry_creator'
    autoload :StateTransition, 'ledger_accountable/ledger_item/state_transition'

    extend ActiveSupport::Concern

    class InitializationError < StandardError
    end

    class InvalidLedgerOwnerError < InitializationError
    end

    # Toggle for whether ledger entry creation should be required for updates to
    # LedgerAccountable objects.
    # If set to `true`, failed ledger entries will roll back all changes.
    # Defaults to all non-production environments.
    mattr_accessor :require_successful_entries
    @@require_successful_entries = !Rails.env.production?

    # The time at which ledger entries began.
    # Defaults to Unix Epoch (1970-01-01 00:00:00 +0000)
    mattr_accessor :epoch
    @@epoch = Time.at(0)

    included do
      has_many :ledger_entries, as: :ledger_item

      # around_[action] are used below to ensure that these callbacks run after model callbacks
      # which may modify object values in a commit lifecycle
      around_create :process_ledger_transition
      around_update :process_ledger_transition
      around_destroy :process_ledger_transition
      # the owner of the ledger entries
      class_attribute :ledger_owner
      # the name of the attribute or method which determines the ledger amount
      class_attribute :ledger_amount_attribute
      # the name of the attribute or method which determines the ledger amount
      class_attribute :ledger_net_amount_method
      # the type of ledger entry to create - debit or credit
      class_attribute :transaction_type
      # attributes of the LedgerAccountable that should trigger a ledger entry when changed
      class_attribute :ledger_attributes
    end

    class_methods do
      # registers the model as a ledger item for ledger_owner,
      # to be updated when the provided attributes (or ledger owner) are changed
      def track_ledger(ledger_owner, options = {})
        validate_and_assign_ledger_owner(ledger_owner)
        validate_and_assign_transaction_type(options)
        validate_and_assign_ledger_amount_attribute(options)
        validate_net_amount_method(options)
        validate_and_assign_ledger_attributes(options)
      end

      def validate_and_assign_ledger_owner(ledger_owner)
        # verify that an instance of the LedgerAccountable model can respond to ledger_owner
        unless instance_methods.include?(ledger_owner)
          raise InvalidLedgerOwnerError, "LedgerAccountable::LedgerItem model #{model_name} must respond to the provided value for ledger_owner (#{ledger_owner})."
        end

        self.ledger_owner = ledger_owner
      end

      def validate_and_assign_transaction_type(options)
        if options[:type].present?
          raise 'LedgerAccountable type must be :debit or :credit' unless %i[debit credit].include?(options[:type])

          self.transaction_type = options[:type]
        else
          self.transaction_type = :credit
        end
      end

      def validate_and_assign_ledger_amount_attribute(options)
        raise "track_ledger :amount is required in #{model_name}" unless options[:amount].present?
        raise 'track_ledger :amount must be a symbol' unless options[:amount].is_a?(Symbol)

        self.ledger_amount_attribute = options[:amount]
      end

      def validate_net_amount_method(options)
        return unless options[:net_amount].present?
        raise 'track_ledger :net_amount must be a symbol' unless options[:net_amount].is_a?(Symbol)

        self.ledger_net_amount_method = options[:net_amount]
      end

      def validate_and_assign_ledger_attributes(options)
        # verify that provided ledger attributes are correctly formatted
        if options[:ledger_attributes].present? && options[:ledger_attributes].any? { |attr| !attr.is_a?(Symbol) }
          raise "LedgerAccountable attributes must be symbols. Did you mean #{options[:ledger_attributes].map do |attr|
            ":#{attr}"
          end.join(', ')}?"
        end

        self.ledger_attributes = options[:ledger_attributes]
      end
    end

    # the amount to be recorded in the ledger entry on creation or deletion; typically the full amount on the
    # LedgerAccountable object
    def ledger_amount
      unless respond_to?(self.class.ledger_amount_attribute)
        raise NotImplementedError,
              "LedgerAccountable::LedgerItem model '#{model_name}' specified #{self.class.ledger_amount_attribute} for track_ledger :amount, but does not implement #{self.class.ledger_amount_attribute}"
      end

      ledger_amount_multiplier * (send(self.class.ledger_amount_attribute) || 0)
    end

    # the amount to be recorded in the ledger entry on update; typically a net change to the dollar amount
    # stored on the LedgerAccountable object
    def net_ledger_amount
      if self.class.ledger_net_amount_method
        net_amount_result = send(self.class.ledger_net_amount_method)
        ledger_amount_multiplier * net_amount_result
      else
        unless attribute_method?(self.class.ledger_amount_attribute.to_s)
          # if a method is provided to compute ledger_amount,
          logger.warn "
LedgerAccountable::LedgerItem model '#{model_name}' appears to use a method for track_ledger :amount, \
but did not provide an option for :net_amount. This can lead to unexpected ledger entry amounts when modifying #{model_name}.
"
        end

        previous_ledger_amount = ledger_amount_multiplier * attribute_was(self.class.ledger_amount_attribute)
        # p 'prev:', previous_ledger_amount, 'cur:', ledger_amount
        ledger_amount - (previous_ledger_amount || 0)
      end
    end

    def ledger_attributes_changed?
      # if no ledger attributes are specified, only trigger if the balance changed
      return false if ledger_attributes.blank?

      changed_attributes.keys.any? { |key| ledger_attributes.include?(key.to_sym) }
    end

    def would_change_ledger_balance?
      net_ledger_amount != 0
    end

    def current_owner
      send(self.class.ledger_owner)
    end

    def previous_owner
      if current_owner.nil?
        # if the owner was removed, get the owner of its last ledger entry
        ledger_entries.reload.last&.owner
      else
        # otherwise get the owner from the last entry NOT for its current owner
        ledger_entries.reload.where.not(owner: current_owner).last&.owner
      end
    end

    def build_ledger_metadata
      # can be overridden to return a hash of metadata values
      {}
    end

    def last_entry_was?(entry_type)
      if current_owner.present?
        ledger_entries.reload.where(owner: current_owner).last&.entry_type == entry_type
      elsif previous_owner.present?
        ledger_entries.reload.where(owner: previous_owner).last&.entry_type == entry_type
      else
        false
      end
    end

    # An overrideable method to determine if the object should be persisted in the ledger
    #
    # For example, payments should not be recorded in a ledger until they're finalized
    # by default, a LedgerAccountable should persist in a ledger if has a ledger_owner via
    # track_ledger
    def should_persist_in_ledger?
      # warning log if the ledger owner is not set - the LedgerAccountable model must
      # include track_ledger
      if self.class.ledger_owner.blank?
        Rails.logger.warn "LedgerAccountable::LedgerItem model #{model_name} must include track_ledger to use ledger functionality"
      end

      self.class.ledger_owner.present? && has_current_or_previous_ledger?
    end

    def entries_for_current_owner?
      ledger_entries.reload.where(owner: current_owner).any?
    end

    def entries_for_previous_owner?
      ledger_entries.reload.where(owner: previous_owner).any?
    end

    def to_be_destroyed?
      @_destroy_callback_already_called ||= false
    end

    private

    def process_ledger_transition(&block)
      StateTransition.execute(self, &block)
    end

    def ledger_amount_multiplier
      self.class.transaction_type == :credit ? 1 : -1
    end

    def has_current_or_previous_ledger?
      previous_owner.present? || current_owner.present?
    end
  end
end

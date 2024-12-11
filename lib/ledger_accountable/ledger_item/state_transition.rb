# frozen_string_literal: true

module LedgerAccountable
  module LedgerItem
    # Manages ledger entry creation during model lifecycle changes.
    # Determines which entries are needed (addition, deletion, modification) and
    # ensures all entries are created within the same transaction as the model changes.
    #
    # Simplified control flow:
    # Am I already in a ledger?
    #   YES
    #     am I still in that ledger?
    #       YES
    #         has my amount changed?
    #           YES
    #             => create entry with the net change
    #           NO
    #             => no update unless overridden
    #       NO
    #         => create a deletion ledger entry
    #         do I have a new ledger?
    #           YES
    #             => create a new ledger entry
    #   NO
    #     => create a new ledger entry
    class StateTransition
      def self.execute(item, &block)
        new(item).execute(&block)
      end

      def initialize(item)
        @item = item
      end

      def execute(&block)
        return yield unless should_record_entry?

        # Compute all values that depend on object state BEFORE the save
        ledger_entries_to_create = determine_required_entries
        metadata = @item.build_ledger_metadata

        ActiveRecord::Base.transaction do
          with_required_save(&block)
          # Create all necessary entries after the save
          ledger_entries_to_create.each do |entry_params|
            record_entry(
              owner: entry_params[:owner],
              amount: entry_params[:amount],
              entry_type: entry_params[:entry_type],
              metadata: metadata
            )
          end
        end
      end

      private

      def with_required_save
        # attempt to save or destroy the object
        commit_successful = yield

        # Proceed only if the save or destroy operation was successful
        raise ActiveRecord::Rollback if !commit_successful && LedgerItem.require_successful_entries
      end

      def should_record_entry?
        return false unless @item.should_persist_in_ledger?

        if @item.to_be_destroyed?
          true
        else
          should_record_addition? || should_record_update? || should_record_removal?
        end
      end

      def determine_required_entries
        entries = []

        if @item.to_be_destroyed?
          entries << build_destruction_entry
        else
          entries << build_removal_entry if should_record_removal?
          entries << build_addition_entry if should_record_addition?
          entries << build_modification_entry if should_record_update?
        end

        entries
      end

      def build_destruction_entry
        {
          type: @item.transaction_type,
          entry_type: :deletion,
          owner: @item.current_owner,
          amount: -@item.ledger_amount
        }
      end

      def build_removal_entry
        {
          type: @item.transaction_type,
          entry_type: :deletion,
          owner: @item.previous_owner,
          amount: -@item.ledger_amount
        }
      end

      def build_addition_entry
        {
          type: @item.transaction_type,
          entry_type: :addition,
          owner: @item.current_owner,
          amount: @item.ledger_amount
        }
      end

      def build_modification_entry
        {
          type: @item.transaction_type,
          entry_type: :modification,
          owner: @item.current_owner,
          amount: @item.net_ledger_amount
        }
      end

      def record_entry(owner:, amount:, entry_type:, metadata:)
        EntryCreator.create(
          item: @item,
          owner: owner,
          amount: amount,
          type: @item.transaction_type,
          entry_type: entry_type,
          metadata: metadata
        )
      rescue ActiveRecord::RecordInvalid => e
        raise e if LedgerItem.require_successful_entries
      end

      def determine_owner
        case determine_entry_type
        when :deletion
          if @item.to_be_destroyed?
            # the item is being destroyed, so use its current owner
            @item.current_owner
          else
            # the item is removed from the ledger, so use its previous owner
            @item.previous_owner
          end
        else
          @item.current_owner
        end
      end

      def calculate_amount
        case determine_entry_type
        when :modification
          @item.net_ledger_amount
        when :deletion
          if @item.current_owner.present?
            -@item.ledger_amount
          else
            @item.net_ledger_amount
          end
        else
          @item.ledger_amount
        end
      end

      def determine_entry_type
        if @item.to_be_destroyed?
          :deletion
        elsif should_record_removal?
          :deletion
        elsif should_record_addition?
          :addition
        else
          :modification
        end
      end

      def should_record_addition?
        return false unless @item.current_owner.present?

        !@item.entries_for_current_owner? || @item.last_entry_was?('deletion')
      end

      def should_record_removal?
        if @item.current_owner.nil?
          @item.entries_for_previous_owner? && !@item.last_entry_was?('deletion')
        elsif @item.previous_owner.present? && @item.current_owner.present?
          @item.entries_for_previous_owner? &&
            @item.ledger_entries.where(owner: @item.previous_owner).last&.entry_type != 'deletion'
        else
          false
        end
      end

      def should_record_update?
        return false unless @item.should_persist_in_ledger?

        if @item.entries_for_current_owner?
          @item.ledger_attributes_changed? || @item.would_change_ledger_balance?
        else
          false
        end
      end
    end
  end
end

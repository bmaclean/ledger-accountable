class LedgerEntry < ActiveRecord::Base
  # used for internationalization via config/locales/ledger.en.yml
  TRANSLATION_PREFIX = 'ledger'.freeze

  belongs_to :owner, polymorphic: true, optional: false
  belongs_to :ledger_item, polymorphic: true, optional: false

  enum entry_type: { addition: 0, deletion: 1, modification: 2 }
  enum transaction_type: { debit: 0, credit: 1 }

  store :metadata, coder: JSON

  validates :transaction_type, presence: true
  validates :amount_cents, presence: true
  validates :entry_type, presence: true

  scope :debits, -> { where(transaction_type: :debit) }
  scope :credits, -> { where(transaction_type: :credit) }
  scope :with_ledger_item_type, -> (type) { where(ledger_item_type: type) }

  def to_itemized_s(line_type = :line)
    I18n.t!("#{TRANSLATION_PREFIX}.#{ledger_item_type.constantize.model_name.param_key}.#{line_type}",
            **metadata.symbolize_keys)
  rescue I18n::MissingTranslationData, I18n::MissingInterpolationArgument
    I18n.t "#{TRANSLATION_PREFIX}.default.#{line_type}",
           default: ledger_item_type,
           model_name: ledger_item_type.humanize
  end
end

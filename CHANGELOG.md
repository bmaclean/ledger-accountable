## 0.1.5.pre

- Add default `ledger_entries` read-performance indexes to new-install generator migration.
- Add `rails generate ledger_accountable --add-indexes` upgrade path for existing installations.
- Add additive index migration template with idempotent guards (`index_exists?`) and adapter-aware behavior:
  - PostgreSQL: `algorithm: :concurrently` with `disable_ddl_transaction!`
  - Other adapters: standard `add_index`
- Document existing-install upgrade flow and default index set in README.

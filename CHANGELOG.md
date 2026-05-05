## 0.1.8.pre

- Switch gem publish workflow to RubyGems Trusted Publishing (OIDC) via `rubygems/release-gem@v1`.
- Remove API-key/OTP-based push logic from release workflow.

## 0.1.7.pre

- Add `spec.license = 'MIT'` to gemspec to satisfy RubyGems license metadata expectations.

## 0.1.6.pre

- Pin GitHub Actions workflows to `ubuntu-22.04` to restore Ruby `3.0.6` compatibility for CI and gem publishing.

## 0.1.5.pre

- Add default `ledger_entries` read-performance indexes to new-install generator migration.
- Add `rails generate ledger_accountable --add-indexes` upgrade path for existing installations.
- Add additive index migration template with idempotent guards (`index_exists?`) and adapter-aware behavior:
  - PostgreSQL: `algorithm: :concurrently` with `disable_ddl_transaction!`
  - Other adapters: standard `add_index`
- Document existing-install upgrade flow and default index set in README.

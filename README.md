<p align="center">
  <img src="assets/branding/moopro-icon-master.png" alt="moopro" width="112" />
</p>

<h1 align="center">moopro</h1>

<p align="center">
  <strong>An open source, end-to-end encrypted app for tracking and planning your money and investments.</strong><br />
  Budgets, bank accounts, shares and crypto in one place, readable only by you.
</p>

<p align="center">
  <a href="https://moopro.sonibla.com">Website</a> ·
  <a href="https://app.moopro.sonibla.com">Open the web app</a>
</p>

---

This directory is the **Flutter client**: one codebase for Android, iOS, web,
Linux, macOS and Windows. It does all the real work on-device: encryption,
decryption, balance computation, charts, statement parsing and market-data
fetching. The sync server is only an encrypted blob store and sync API; it
never sees plaintext.

## Highlights

- **Zero-knowledge E2EE.** A random 256-bit vault key is wrapped by a key derived
  from your password with Argon2id. Every record is sealed with AES-256-GCM
  before it leaves the device. Even full database access reveals nothing.
- **One idea for "where money is".** Banks, brokers and budgets are all
  *containers* that can hold fiat, shares and crypto at the same time. Budgets nest
  into sub-budgets, and holder totals always reconcile with budget totals.
- **Charts you can explore.** A sunburst of the budget tree, stacked balance history,
  a dashed forecast built from recurring and future transactions, a Sankey view of
  budget transfers, and a movable date cursor that drives the whole page.
- **Statement import.** PDF, CSV and XLSX statements (and `.zip` archives, including
  password-protected ones) are parsed on-device, reconciled against balances, matched
  against already-recorded transactions and de-duplicated before you commit.
- **Investments.** Stocks, ETFs and crypto, trades, manual prices, and optional
  on-device price fetching with your own AlphaVantage key. The backend never learns
  what you hold.
- **Works offline, works with many vaults.** Create a vault with no account and no
  server, attach it to an account later, and keep several fully isolated vaults on
  one device.
- **Hide amounts**, light and dark themes, encrypted backup and restore.

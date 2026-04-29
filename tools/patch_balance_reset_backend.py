from __future__ import annotations

import argparse
import re
from pathlib import Path


def replace_block(text: str, start_pat: str, end_pat: str, replacement: str) -> tuple[str, bool]:
    start = re.search(start_pat, text, flags=re.M)
    if not start:
        return text, False
    end = re.search(end_pat, text[start.end() :], flags=re.M)
    if not end:
        return text, False
    abs_end = start.end() + end.end()
    return text[: start.start()] + replacement + text[abs_end:], True


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend-root", required=True)
    args = ap.parse_args()

    backend_root = Path(args.backend_root).resolve()
    path = backend_root / "controllers" / "customerDebtController.js"
    original = path.read_text(encoding="utf-8")
    text = original

    # 1) buildPaymentsMapForAccounts: sum only for the latest snapshot (resets with new snapshot).
    new_payments_map = """// Sum collections for a specific snapshot so balances reset when finance imports a new statement.
const buildPaymentsMapForAccounts = async (snapshotId, accountNumbers) => {
  const accounts = [...new Set((accountNumbers || [])
    .map((v) => String(v || '').trim())
    .filter(Boolean))];

  const totalsMap = new Map();
  if (!snapshotId || !accounts.length) return totalsMap;

  const rows = await CustomerDebtCollection.aggregate([
    { $match: { snapshotId, customerAccountNumber: { $in: accounts } } },
    { $group: { _id: '$customerAccountNumber', total: { $sum: '$amount' } } },
  ]);

  for (const row of rows) {
    const key = String(row._id || '').trim();
    if (!key) continue;
    totalsMap.set(key, Number(row.total || 0));
  }

  return totalsMap;
};
"""
    text, ok = replace_block(
        text,
        r"^// Sum collections across \*all\* snapshots so balances don't reset when finance\s*$\n^// imports a new customer statement\.\s*$\n^const buildPaymentsMapForAccounts = async \(accountNumbers\) => \{\s*$",
        r"^\};\s*$",
        new_payments_map,
    )
    if not ok:
        raise SystemExit("Failed to patch buildPaymentsMapForAccounts block")

    # 2) calculateCurrentBalance: only count collections for the latest snapshot.
    new_calc_balance = """const calculateCurrentBalance = async (snapshot, accountNumber) => {
  const row = snapshot.rows.find((item) => item.accountNumber === accountNumber);
  const baseBalance = Number(row?.netBalance || 0);

  const totalPaid = await CustomerDebtCollection.aggregate([
    {
      $match: {
        snapshotId: snapshot._id,
        customerAccountNumber: accountNumber,
      },
    },
    {
      $group: {
        _id: null,
        total: { $sum: '$amount' },
      },
    },
  ]);

  const paid = Number(totalPaid[0]?.total || 0);

  return {
    baseBalance,
    paid,
    remaining: baseBalance - paid,
  };
};
"""
    text, ok = replace_block(
        text,
        r"^const calculateCurrentBalance = async \(snapshot, accountNumber\) => \{\s*$",
        r"^\};\s*$",
        new_calc_balance,
    )
    if not ok:
        raise SystemExit("Failed to patch calculateCurrentBalance block")

    # 3) getLatestCustomerDebtSnapshot / listCustomers: payments map per snapshot.
    text2 = re.sub(
        r"buildPaymentsMapForAccounts\(snapshot\.rows\.map\(\(row\) => row\.accountNumber\)\)",
        "buildPaymentsMapForAccounts(snapshot._id, snapshot.rows.map((row) => row.accountNumber))",
        text,
    )
    text = text2

    # 4) createCollection must set snapshotId (schema requires it).
    if "snapshotId: snapshot._id," not in text:
        text, n = re.subn(
            r"(const collection = await CustomerDebtCollection\.create\(\{\s*\n)",
            r"\1      snapshotId: snapshot._id,\n",
            text,
            count=1,
        )
        if n != 1:
            raise SystemExit("Failed to inject snapshotId into createCollection")

    # 5) getCustomerLedger totals should be per latest snapshot (collections stay visible historically).
    ledger_start = r"^\s*const totals = collections\.reduce\(\(acc, item\) => \{\s*$"
    ledger_end = r"^\s*\}\);\s*$"
    ledger_repl = """    const currentSnapshotId = snapshot._id.toString();
    const totals = collections.reduce((acc, item) => {
      if (String(item.snapshotId) !== currentSnapshotId) return acc;
      acc.totalCollected += Number(item.amount || 0);
      if (item.paymentMethod === 'cash') acc.cash += Number(item.amount || 0);
      if (item.paymentMethod === 'card') acc.card += Number(item.amount || 0);
      if (item.paymentMethod === 'bank_transfer') acc.bankTransfer += Number(item.amount || 0);
      return acc;
    }, {
      totalCollected: 0,
      cash: 0,
      card: 0,
      bankTransfer: 0,
    });
"""

    # Restrict replacement to within getCustomerLedger by finding the first occurrence after its export definition.
    ledger_anchor = re.search(r"^exports\.getCustomerLedger\s*=\s*async\s*\(req,\s*res\)\s*=>\s*\{\s*$", text, flags=re.M)
    if not ledger_anchor:
        raise SystemExit("Failed to locate exports.getCustomerLedger block")
    segment = text[ledger_anchor.start() :]
    segment2, ok = replace_block(segment, ledger_start, ledger_end, ledger_repl)
    if not ok:
        raise SystemExit("Failed to patch ledger totals block")
    text = text[: ledger_anchor.start()] + segment2

    if text == original:
        print("No changes made (already patched).")
        return

    path.write_text(text, encoding="utf-8", newline="\n")
    print(f"Patched: {path}")


if __name__ == "__main__":
    main()

from __future__ import annotations

import re
from pathlib import Path

FILE = Path("lib/screens/order_management/treasury/customer_accounts_screen.dart")


def _slice_dialog(text: str) -> tuple[str, str, str]:
    start_marker = "Future<void> _showDirectReceiptDialog() async {"
    end_marker = "Future<void> _reviewDeposit"
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end < 0 or end <= start:
        raise SystemExit("Could not locate _showDirectReceiptDialog block.")
    return text[:start], text[start:end], text[end:]


def main() -> None:
    text = FILE.read_text(encoding="utf-8")
    head, segment, tail = _slice_dialog(text)

    if "Future<_DebtCustomer?> pickCustomer() async" not in segment:
        raise SystemExit("pickCustomer helper not found in receipt dialog.")

    # Make dialog content scrollable and a bit wider (prevents RenderFlex overflow).
    segment = re.sub(
        r"child:\s*SizedBox\(\s*\r?\n\s*width:\s*480,\s*\r?\n\s*child:\s*Column\(",
        "child: SizedBox(\n              width: 520,\n              child: SingleChildScrollView(\n                child: Column(",
        segment,
        count=1,
    )

    # Close SingleChildScrollView after the Column.
    segment = segment.replace(
        "                ],\n              ),\n            ),",
        "                ],\n              ),\n            ),\n              ),",
        1,
    )

    dropdown_pat = re.compile(
        r"^\s*DropdownButtonFormField<_DebtCustomer>\([\s\S]*?^\s*\),\s*$",
        re.M,
    )

    replacement = """                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await pickCustomer();
                      if (picked == null) return;
                      setModalState(() => selectedCustomer = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'العميل',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedCustomer?.displayName ?? 'اختر العميل',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),"""

    segment2, n = dropdown_pat.subn(replacement, segment, count=1)
    if n != 1:
        raise SystemExit(f"Failed to replace customer dropdown (matches={n}).")
    segment = segment2

    FILE.write_text(head + segment + tail, encoding="utf-8", newline="\n")
    print("Patched receipt dialog UI.")


if __name__ == "__main__":
    main()


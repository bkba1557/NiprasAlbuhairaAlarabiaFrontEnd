from __future__ import annotations

import re
from pathlib import Path


FILE = Path("lib/screens/order_management/treasury/customer_accounts_screen.dart")


def slice_dialog(text: str) -> tuple[str, str, str]:
    start_marker = "Future<void> _showDirectReceiptDialog() async {"
    end_marker = "Future<void> _reviewDeposit"
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end < 0 or end <= start:
        raise SystemExit("Could not locate _showDirectReceiptDialog block.")
    return text[:start], text[start:end], text[end:]


def main() -> None:
    text = FILE.read_text(encoding="utf-8")
    head, segment, tail = slice_dialog(text)

    # Replace the Form content SizedBox child entirely (safer than partial edits).
    pat = re.compile(
        r"(content:\s*Form\(\s*\n\s*key:\s*formKey,\s*\n\s*child:\s*)SizedBox\([\s\S]*?\n\s*\)\s*,\s*\n\s*\)\s*,",
        re.M,
    )

    replacement_child = """SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        return (parsed == null || parsed <= 0)
                            ? 'مبلغ غير صالح'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                        DropdownMenuItem(value: 'card', child: Text('شبكة')),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('تحويل بنكي'),
                        ),
                      ],
                      onChanged: (value) => setModalState(() {
                        paymentMethod = value ?? 'cash';
                      }),
                    ),
                    if (paymentMethod == 'bank_transfer') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_BankAccount>(
                        initialValue: selectedBank,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'الحساب البنكي'),
                        items: _bankAccounts
                            .map(
                              (item) => DropdownMenuItem<_BankAccount>(
                                value: item,
                                child: Text(
                                  item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setModalState(() {
                          selectedBank = value;
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
            )"""

    segment2, n = pat.subn(r"\1" + replacement_child + ",\n          ),", segment, count=1)
    if n != 1:
        raise SystemExit(f"Failed to replace receipt dialog content block (matches={n}).")

    FILE.write_text(head + segment2 + tail, encoding="utf-8", newline="\n")
    print("Fixed receipt dialog content block.")


if __name__ == "__main__":
    main()


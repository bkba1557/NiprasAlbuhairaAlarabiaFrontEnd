from __future__ import annotations

from pathlib import Path


FILE = Path("lib/screens/order_management/treasury/customer_accounts_screen.dart")
START = "  Future<void> _showDirectReceiptDialog() async {"
END = "  Future<void> _reviewDeposit"


NEW_BLOCK = """  Future<void> _showDirectReceiptDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    _DebtCustomer? selectedCustomer =
        _customers.isNotEmpty ? _customers.first : null;
    String paymentMethod = 'cash';
    _BankAccount? selectedBank =
        _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
    final formKey = GlobalKey<FormState>();

    Future<_DebtCustomer?> pickCustomer() async {
      final searchController = TextEditingController();
      try {
        return await showDialog<_DebtCustomer>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setState) {
              final query = searchController.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? _customers
                  : _customers.where((c) {
                      final haystack =
                          '${c.customerName} ${c.accountNumber}'.toLowerCase();
                      return haystack.contains(query);
                    }).toList();

              return AlertDialog(
                title: const Text('اختيار العميل'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'بحث بالاسم أو رقم الحساب',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(
                                item.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(item.accountNumber),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ],
              );
            },
          ),
        );
      } finally {
        searchController.dispose();
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('سند قبض من العميل'),
            content: Form(
              key: formKey,
              child: SizedBox(
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
                        decoration:
                            const InputDecoration(labelText: 'طريقة الدفع'),
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
                          decoration: const InputDecoration(
                            labelText: 'الحساب البنكي',
                          ),
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() ||
                      selectedCustomer == null) {
                    return;
                  }

                  await ApiService.post('/customer-debts/collections', {
                    'customerAccountNumber': selectedCustomer!.accountNumber,
                    'amount': double.parse(amountController.text.trim()),
                    'paymentMethod': paymentMethod,
                    'bankAccountId': paymentMethod == 'bank_transfer'
                        ? selectedBank?.id
                        : null,
                    'bankName': paymentMethod == 'bank_transfer'
                        ? selectedBank?.bankName
                        : '',
                    'notes': notesController.text.trim(),
                  });

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadAll();
                },
                child: const Text('تسجيل'),
              ),
            ],
          );
        },
      ),
    );
  }
"""


def main() -> None:
    text = FILE.read_text(encoding="utf-8")
    start = text.find(START)
    end = text.find(END)
    if start < 0 or end < 0 or end <= start:
        raise SystemExit("Could not locate receipt dialog block markers.")

    new_text = text[:start] + NEW_BLOCK + "\n\n" + text[end:]
    FILE.write_text(new_text, encoding="utf-8", newline="\n")
    print("Replaced _showDirectReceiptDialog block.")


if __name__ == "__main__":
    main()


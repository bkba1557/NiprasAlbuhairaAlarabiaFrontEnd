$ErrorActionPreference = "Stop"

$path = "lib/screens/order_management/treasury/customer_debt_collector_screen.dart"

function Read-Text($p) { Get-Content -Raw -Encoding utf8 $p }
function Write-Text($p, $content) {
  $normalized = $content -replace "`r`n", "`n"
  $crlf = $normalized -replace "`n", "`r`n"
  Set-Content -Encoding utf8 -Path $p -Value $crlf
}

$text = Read-Text $path
$lf = $text -replace "`r`n","`n"

$startMarker = "Future<void> _exportCollections({required String format}) async {"
$endMarker = "Future<void> _pickDepositAttachment() async {"

$start = $lf.IndexOf($startMarker)
if ($start -lt 0) { throw "Start marker not found." }
$end = $lf.IndexOf($endMarker, $start)
if ($end -lt 0) { throw "End marker not found." }

$prefix = $lf.Substring(0, $start)
$suffix = $lf.Substring($end)

$replacement = @'
  Future<void> _exportCollections({required String format}) async {
    try {
      final date = _selectedDate ?? DateTime.now();
      final dateOnly = DateFormat('yyyy-MM-dd').format(date);

      final query =
          'reportType=customer_debt_collections&startDate=$dateOnly&endDate=$dateOnly';
      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'collections_${dateOnly}_$fileStamp.$ext',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير الملف')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _exportCustomerLedger({required String format}) async {
    try {
      final customer = _selectedCustomer;
      if (customer == null) return;

      final query =
          'reportType=customer_debt_ledger&customerAccountNumber=${Uri.encodeComponent(customer.accountNumber)}';
      final endpoint = format == 'pdf'
          ? '/reports/export/pdf?$query'
          : '/reports/export/excel?$query';

      final response = await ApiService.download(endpoint);
      final fileStamp = DateTime.now().millisecondsSinceEpoch;
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      await saveAndLaunchFile(
        response.bodyBytes,
        'ledger_${customer.accountNumber}_$fileStamp.$ext',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير الملف')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

'@

$updated = $prefix + $replacement + $suffix
Write-Text $path $updated

Write-Host "Rewrote export methods with try/catch + safe filenames."


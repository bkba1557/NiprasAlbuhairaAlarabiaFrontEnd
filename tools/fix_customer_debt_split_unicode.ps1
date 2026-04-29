$ErrorActionPreference = "Stop"

$backendRoot = "C:\Users\Al-Buhaira\Desktop\Order-Track\backend"
$controllerPath = Join-Path $backendRoot "controllers\customerDebtController.js"

function Read-TextUtf8($path) {
  return Get-Content -Path $path -Raw -Encoding utf8
}

function Write-TextUtf8Crlf($path, $content) {
  $normalized = $content -replace "`r`n", "`n"
  $crlf = $normalized -replace "`n", "`r`n"
  Set-Content -Path $path -Value $crlf -Encoding utf8
}

$controller = Read-TextUtf8 $controllerPath
$controllerLf = $controller -replace "`r`n", "`n"

$start = $controllerLf.IndexOf("exports.createSplitCollection = async (req, res) => {")
if ($start -lt 0) { throw "createSplitCollection not found." }

$afterStart = $controllerLf.IndexOf("exports.listCollections = async (req, res) => {", $start)
if ($afterStart -lt 0) { throw "listCollections marker not found after createSplitCollection." }

$prefix = $controllerLf.Substring(0, $start)
$suffix = $controllerLf.Substring($afterStart)

# JS with only ASCII + unicode escapes (safe under any codepage).
$replacement = @'
exports.createSplitCollection = async (req, res) => {
  try {
    if (!isCollectorUser(req.user) && !isFinanceUser(req.user)) {
      return res.status(403).json({ success: false, error: '\u063a\u064a\u0631 \u0645\u0635\u0631\u062d \u0628\u0627\u0644\u062a\u062d\u0635\u064a\u0644' });
    }

    const snapshot = await getLatestSnapshot();
    if (!snapshot) {
      return res.status(400).json({ success: false, error: '\u0644\u0627 \u064a\u0648\u062c\u062f \u0643\u0634\u0641 \u0645\u062f\u064a\u0648\u0646\u064a\u0627\u062a \u0645\u0633\u062a\u0648\u0631\u062f' });
    }

    const customerAccountNumber = String(req.body.customerAccountNumber || '').trim();
    const cashAmount = Number(req.body.cashAmount || 0);
    const cardAmount = Number(req.body.cardAmount || 0);
    const bankTransferAmount = Number(req.body.bankTransferAmount || 0);
    const bankAccountId = String(req.body.bankAccountId || '').trim() || null;
    const bankName = normalizeText(req.body.bankName);
    const referenceName = normalizeText(req.body.referenceName);
    const notes = normalizeText(req.body.notes);

    if (!customerAccountNumber) {
      return res.status(400).json({ success: false, error: '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u062d\u0635\u064a\u0644 \u063a\u064a\u0631 \u0645\u0643\u062a\u0645\u0644\u0629' });
    }

    const amounts = [cashAmount, cardAmount, bankTransferAmount];
    if (amounts.some((value) => !Number.isFinite(value) || value < 0)) {
      return res.status(400).json({ success: false, error: '\u0642\u064a\u0645 \u0627\u0644\u0645\u0628\u0627\u0644\u063a \u063a\u064a\u0631 \u0635\u0627\u0644\u062d\u0629' });
    }

    const totalAmount = cashAmount + cardAmount + bankTransferAmount;
    if (totalAmount <= 0) {
      return res.status(400).json({ success: false, error: '\u0623\u062f\u062e\u0644 \u0645\u0628\u0644\u063a \u062a\u062d\u0635\u064a\u0644 \u0648\u0627\u062d\u062f \u0639\u0644\u0649 \u0627\u0644\u0623\u0642\u0644' });
    }

    const snapshotRow = snapshot.rows.find((row) => row.accountNumber === customerAccountNumber);
    if (!snapshotRow) {
      return res.status(404).json({ success: false, error: '\u0627\u0644\u0639\u0645\u064a\u0644 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f \u0641\u064a \u0622\u062e\u0631 \u0643\u0634\u0641' });
    }

    let bankAccount = null;
    if (bankTransferAmount > 0) {
      if (bankAccountId) {
        bankAccount = await CustomerDebtBankAccount.findById(bankAccountId);
      }
      if (!bankAccount && !bankName) {
        return res.status(400).json({ success: false, error: '\u064a\u062c\u0628 \u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0628\u0646\u0643 \u0644\u0644\u062a\u062d\u0648\u064a\u0644 \u0627\u0644\u0628\u0646\u0643\u064a' });
      }
      if (!referenceName) {
        return res.status(400).json({ success: false, error: '\u0627\u062f\u062e\u0644 \u0627\u0633\u0645 \u0627\u0644\u0645\u062d\u0648\u0644 / \u0627\u0644\u0645\u0631\u062c\u0639 \u0644\u0644\u062a\u062d\u0648\u064a\u0644' });
      }
    }

    const balanceInfo = await calculateCurrentBalance(snapshot, customerAccountNumber);

    const collectorId = isCollectorUser(req.user) ? req.user._id : (req.body.collectorId || req.user._id);
    const collectorUser = await User.findById(collectorId).select('name role company');
    if (!collectorUser) {
      return res.status(400).json({ success: false, error: '\u0627\u0644\u0645\u062d\u0635\u0644 \u0627\u0644\u0645\u062d\u062f\u062f \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f' });
    }

    const now = new Date();
    const batchId = `${now.getTime()}_${Math.random().toString(36).slice(2, 8)}`;
    let remaining = balanceInfo.remaining;
    const docsToCreate = [];

    const pushDoc = (paymentMethod, amount) => {
      if (!amount || amount <= 0) return;
      const remainingAfter = remaining - amount;
      docsToCreate.push({
        snapshotId: snapshot._id,
        customerAccountNumber,
        customerName: snapshotRow.customerName,
        amount,
        paymentMethod,
        bankAccountId: paymentMethod === 'bank_transfer' ? (bankAccount?._id || null) : null,
        bankName: paymentMethod === 'bank_transfer' ? (bankAccount?.bankName || bankName) : '',
        referenceName: paymentMethod === 'bank_transfer' ? referenceName : '',
        notes,
        remainingBefore: remaining,
        remainingAfter,
        collectorId: collectorUser._id,
        collectorName: collectorUser.name,
        createdBy: req.user._id,
        createdByName: req.user.name,
        source: isFinanceUser(req.user) ? 'finance' : 'collector',
        createdAt: now,
        updatedAt: now,
        batchId,
      });
      remaining = remainingAfter;
    };

    pushDoc('cash', cashAmount);
    pushDoc('card', cardAmount);
    pushDoc('bank_transfer', bankTransferAmount);

    const created = await CustomerDebtCollection.insertMany(docsToCreate, { ordered: true });

    await Activity.create({
      activityType: '\u0625\u0636\u0627\u0641\u0629',
      description: `\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u062a\u062d\u0635\u064a\u0644 \u0645\u062c\u0645\u0639 \u0644\u0644\u0639\u0645\u064a\u0644 ${snapshotRow.customerName}`,
      performedBy: req.user._id,
      performedByName: req.user.name,
      changes: {
        customer: snapshotRow.customerName,
        accountNumber: customerAccountNumber,
        amount: String(totalAmount),
        remainingAfter: String(remaining),
      },
    });

    await notifyFinanceAndStakeholders({
      company: req.user.company,
      title: `\u062a\u062d\u0635\u064a\u0644 \u062c\u062f\u064a\u062f \u0644\u0644\u0639\u0645\u064a\u0644 ${snapshotRow.customerName}`,
      message: `\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u062a\u062d\u0635\u064a\u0644 \u0628\u0645\u0628\u0644\u063a ${totalAmount} \u0645\u0646 \u0627\u0644\u0639\u0645\u064a\u0644 ${snapshotRow.customerName} \u0648\u0627\u0644\u0645\u062a\u0628\u0642\u064a ${remaining}.`,
      data: {
        actorName: req.user.name,
        note: notes,
        changes: {
          '\u0627\u0633\u0645 \u0627\u0644\u0639\u0645\u064a\u0644': snapshotRow.customerName,
          '\u0631\u0642\u0645 \u0627\u0644\u062d\u0633\u0627\u0628': customerAccountNumber,
          '\u0627\u0644\u0645\u0628\u0644\u063a': totalAmount,
          '\u0627\u0644\u0645\u062a\u0628\u0642\u064a': remaining,
          '\u0627\u0644\u0645\u062d\u0635\u0644': collectorUser.name,
        },
      },
      createdBy: req.user._id,
    });

    return res.status(201).json({
      success: true,
      message: '\u062a\u0645 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062a\u062d\u0635\u064a\u0644 \u0628\u0646\u062c\u0627\u062d',
      collections: created.map(serializeCollection),
    });
  } catch (error) {
    console.error('CUSTOMER DEBT SPLIT COLLECTION ERROR:', error);
    return res.status(500).json({ success: false, error: '\u0641\u0634\u0644 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062a\u062d\u0635\u064a\u0644' });
  }
};

'@

$updated = $prefix + $replacement + $suffix
Write-TextUtf8Crlf $controllerPath $updated

Write-Host "Rewrote createSplitCollection using unicode escapes."


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
if ($start -lt 0) {
  throw "createSplitCollection not found in controller."
}

$afterStart = $controllerLf.IndexOf("exports.listCollections = async (req, res) => {", $start)
if ($afterStart -lt 0) {
  throw "listCollections marker not found after createSplitCollection."
}

$prefix = $controllerLf.Substring(0, $start)
$suffix = $controllerLf.Substring($afterStart)

$replacement = @'
exports.createSplitCollection = async (req, res) => {
  try {
    if (!isCollectorUser(req.user) && !isFinanceUser(req.user)) {
      return res.status(403).json({ success: false, error: 'غير مصرح بالتحصيل' });
    }

    const snapshot = await getLatestSnapshot();
    if (!snapshot) {
      return res.status(400).json({ success: false, error: 'لا يوجد كشف مديونيات مستورد' });
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
      return res.status(400).json({ success: false, error: 'بيانات التحصيل غير مكتملة' });
    }

    const amounts = [cashAmount, cardAmount, bankTransferAmount];
    if (amounts.some((value) => !Number.isFinite(value) || value < 0)) {
      return res.status(400).json({ success: false, error: 'قيم المبالغ غير صالحة' });
    }

    const totalAmount = cashAmount + cardAmount + bankTransferAmount;
    if (totalAmount <= 0) {
      return res.status(400).json({ success: false, error: 'أدخل مبلغ تحصيل واحد على الأقل' });
    }

    const snapshotRow = snapshot.rows.find((row) => row.accountNumber === customerAccountNumber);
    if (!snapshotRow) {
      return res.status(404).json({ success: false, error: 'العميل غير موجود في آخر كشف' });
    }

    let bankAccount = null;
    if (bankTransferAmount > 0) {
      if (bankAccountId) {
        bankAccount = await CustomerDebtBankAccount.findById(bankAccountId);
      }
      if (!bankAccount && !bankName) {
        return res.status(400).json({ success: false, error: 'يجب تحديد البنك للتحويل البنكي' });
      }
      if (!referenceName) {
        return res.status(400).json({ success: false, error: 'ادخل اسم المحول / المرجع للتحويل' });
      }
    }

    const balanceInfo = await calculateCurrentBalance(snapshot, customerAccountNumber);

    const collectorId = isCollectorUser(req.user) ? req.user._id : (req.body.collectorId || req.user._id);
    const collectorUser = await User.findById(collectorId).select('name role company');
    if (!collectorUser) {
      return res.status(400).json({ success: false, error: 'المحصل المحدد غير موجود' });
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
      activityType: 'إضافة',
      description: `تم تسجيل تحصيل مجمع للعميل ${snapshotRow.customerName}`,
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
      title: `تحصيل جديد للعميل ${snapshotRow.customerName}`,
      message: `تم تسجيل تحصيل بمبلغ ${totalAmount} من العميل ${snapshotRow.customerName} والمتبقي ${remaining}.`,
      data: {
        actorName: req.user.name,
        note: notes,
        changes: {
          'اسم العميل': snapshotRow.customerName,
          'رقم الحساب': customerAccountNumber,
          'المبلغ': totalAmount,
          'المتبقي': remaining,
          'المحصل': collectorUser.name,
        },
      },
      createdBy: req.user._id,
    });

    return res.status(201).json({
      success: true,
      message: 'تم تسجيل التحصيل بنجاح',
      collections: created.map(serializeCollection),
    });
  } catch (error) {
    console.error('CUSTOMER DEBT SPLIT COLLECTION ERROR:', error);
    return res.status(500).json({ success: false, error: 'فشل تسجيل التحصيل' });
  }
};

'@

$updated = $prefix + $replacement + $suffix
Write-TextUtf8Crlf $controllerPath $updated

Write-Host "Fixed createSplitCollection encoding/text."


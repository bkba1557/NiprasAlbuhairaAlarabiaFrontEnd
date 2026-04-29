$ErrorActionPreference = "Stop"

$backendRoot = "C:\Users\Al-Buhaira\Desktop\Order-Track\backend"
$controllerPath = Join-Path $backendRoot "controllers\customerDebtController.js"
$routesPath = Join-Path $backendRoot "routes\customerDebtRoutes.js"
$collectionModelPath = Join-Path $backendRoot "models\CustomerDebtCollection.js"

function Read-Text($path) {
  return Get-Content -Path $path -Raw -Encoding utf8
}

function Write-Text($path, $content) {
  # Preserve CRLF in backend repo (core.autocrlf=true) for minimal diffs.
  $normalized = $content -replace "`r`n", "`n"
  $crlf = $normalized -replace "`n", "`r`n"
  Set-Content -Path $path -Value $crlf -Encoding utf8
}

function Assert-Contains($text, $needle, $label) {
  if (-not $text.Contains($needle)) {
    throw "Expected block not found: $label"
  }
}

# 1) routes: add /collections/split
$routes = Read-Text $routesPath
if ($routes -notmatch "router\.post\('/collections/split'") {
  $routes = $routes -replace "router\.get\('/collections', customerDebtController\.listCollections\);\s*`r?`nrouter\.post\('/collections', customerDebtController\.createCollection\);",
"router.get('/collections', customerDebtController.listCollections);`nrouter.post('/collections/split', customerDebtController.createSplitCollection);`nrouter.post('/collections', customerDebtController.createCollection);"
}
Write-Text $routesPath $routes

# 2) model: add batchId
$model = Read-Text $collectionModelPath
if ($model -notmatch "batchId") {
  $model = $model -replace "source:\s*\{\s*`r?`n\s*type:\s*String,\s*`r?`n\s*enum:\s*\['collector',\s*'finance'\],\s*`r?`n\s*default:\s*'collector',\s*`r?`n\s*\},",
"source: {`n    type: String,`n    enum: ['collector', 'finance'],`n    default: 'collector',`n  },`n  batchId: {`n    type: String,`n    trim: true,`n    default: '',`n  },"
}
Write-Text $collectionModelPath $model

# 3) controller edits
$controller = Read-Text $controllerPath

# 3a) Replace buildPaymentsMap with buildPaymentsMapForAccounts
$oldBuildMap = @'
const buildPaymentsMap = async (snapshotId) => {
  const collections = await CustomerDebtCollection.find({ snapshotId }).lean();

  const totalsMap = new Map();
  for (const item of collections) {
    const key = String(item.customerAccountNumber || '').trim();
    if (!key) continue;
    totalsMap.set(key, (totalsMap.get(key) || 0) + Number(item.amount || 0));
  }
  return totalsMap;
};
'@

$newBuildMap = @'
// Sum collections across *all* snapshots so balances don't reset when finance
// imports a new customer statement.
const buildPaymentsMapForAccounts = async (accountNumbers) => {
  const accounts = [...new Set((accountNumbers || [])
    .map((v) => String(v || '').trim())
    .filter(Boolean))];

  const totalsMap = new Map();
  if (!accounts.length) return totalsMap;

  const rows = await CustomerDebtCollection.aggregate([
    { $match: { customerAccountNumber: { $in: accounts } } },
    { $group: { _id: '$customerAccountNumber', total: { $sum: '$amount' } } },
  ]);

  for (const row of rows) {
    const key = String(row._id || '').trim();
    if (!key) continue;
    totalsMap.set(key, Number(row.total || 0));
  }

  return totalsMap;
};
'@

Assert-Contains ($controller -replace "`r`n","`n") ($oldBuildMap -replace "`r`n","`n") "buildPaymentsMap()"
$controller = ($controller -replace "`r`n","`n").Replace(($oldBuildMap -replace "`r`n","`n"), ($newBuildMap -replace "`r`n","`n"))

# 3b) calculateCurrentBalance: remove snapshotId filter
$controller = $controller -replace "`n\s*snapshotId:\s*snapshot\._id,\s*`n", "`n"

# 3c) Update callers
$controller = $controller -replace "buildPaymentsMap\(snapshot\._id\)", "buildPaymentsMapForAccounts(snapshot.rows.map((row) => row.accountNumber))"

# 3d) listCollections: stop forcing latest snapshotId, allow optional snapshotId query
$controller = $controller -replace @"
    const query = {};
    const snapshot = await getLatestSnapshot\(\);
    if \(snapshot\) {
      query\.snapshotId = snapshot\._id;
    }
"@, @"
    const query = {};
    if (req.query.snapshotId) {
      query.snapshotId = req.query.snapshotId;
    }
"@

# 3e) Add createSplitCollection export if missing
if ($controller -notmatch "exports\.createSplitCollection") {
  $marker = "`nexports.listCollections = async (req, res) => {"
  $insert = @'

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

    const collectorId = isCollectorUser(req.user)
      ? req.user._id
      : (req.body.collectorId || req.user._id);
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

  Assert-Contains $controller $marker "exports.listCollections marker"
  $controller = $controller.Replace($marker, ($insert + $marker))
}

Write-Text $controllerPath $controller

Write-Host "Backend customer debt patch applied."

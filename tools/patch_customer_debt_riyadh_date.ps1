$ErrorActionPreference = "Stop"

$path = "C:\Users\Al-Buhaira\Desktop\Order-Track\backend\controllers\customerDebtController.js"

function Read-Text($p) { Get-Content -Raw -Encoding utf8 $p }
function Write-Text($p, $content) {
  $normalized = $content -replace "`r`n", "`n"
  $crlf = $normalized -replace "`n", "`r`n"
  Set-Content -Encoding utf8 -Path $p -Value $crlf
}

$text = Read-Text $path
$lf = $text -replace "`r`n","`n"

if ($lf -notmatch "const moment = require\\('moment'\\);") {
  $lf = $lf -replace "const path = require\\('path'\\);\n", "const path = require('path');`nconst moment = require('moment');`n"
}

$old = @'
    if (req.query.date) {
      const start = new Date(`${req.query.date}T00:00:00.000Z`);
      const end = new Date(`${req.query.date}T23:59:59.999Z`);
      query.createdAt = { $gte: start, $lte: end };
    }
'@

$new = @'
    if (req.query.date) {
      const dateOnly = String(req.query.date || '').trim().slice(0, 10);
      const start = moment(dateOnly).utcOffset(180).startOf('day').toDate();
      const end = moment(dateOnly).utcOffset(180).endOf('day').toDate();
      query.createdAt = { $gte: start, $lte: end };
    }
'@

if (-not ($lf.Contains(($old -replace "`r`n","`n")))) {
  throw "Expected date filter block not found; file may have changed."
}

$lf = $lf.Replace(($old -replace "`r`n","`n"), ($new -replace "`r`n","`n"))
Write-Text $path $lf

Write-Host "Patched Riyadh date filtering for customer debt collections."

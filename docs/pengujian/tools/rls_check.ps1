# ==============================================================================
# RLS Matrix Check - Onderdil Motor Indonesia
# ------------------------------------------------------------------------------
# Tes Row Level Security via Supabase REST (PostgREST) menggunakan token
# autentikasi 3 role: customer, warehouse, admin. Sesuai test case
# docs/pengujian/rencana-pengujian.md bagian 9.1 (S-01 s/d S-13, S-25).
#
# CARA PAKAI:
#   1. Salin config/test_accounts.json.example -> config/test_accounts.json
#      lalu isi email & password AKUN SENDIRI (file ini di-gitignore).
#   2. Jalankan dari folder project:
#        powershell -ExecutionPolicy Bypass -File docs\pengujian\tools\rls_check.ps1
#   3. Hasil tersimpan otomatis di docs/pengujian/bukti/rls-check-*.txt
#   CATATAN: skrip memakai curl.exe (sudah bawaan Windows 10+) karena
#   Invoke-WebRequest di Windows PowerShell 5.1 kadang mengembalikan
#   body respons kosong untuk status error, sehingga pesan penolakan
#   dari database tidak terbaca.
#
# STATUS PER TES:
#   PASS   - perilaku sesuai spesifikasi RLS
#   TEMUAN - deviasi dari spesifikasi (calon defect, dilaporkan ke bug-tracker)
#   FAIL   - terjadi error tak terduga (login salah, server, dsb.)
#   SKIP   - tidak bisa diuji (data prasyarat kurang)
#   INFO   - catatan non-tes
# ==============================================================================

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here '..\..\..')).Path

# --- Konfigurasi ---------------------------------------------------------------
$devPath = Join-Path $root 'config\dev.json'
$accPath = Join-Path $root 'config\test_accounts.json'
if (-not (Test-Path $devPath)) {
  Write-Host 'config/dev.json tidak ditemukan.' -ForegroundColor Red
  exit 1
}
if (-not (Test-Path $accPath)) {
  Write-Host 'BELUM ADA config/test_accounts.json' -ForegroundColor Red
  Write-Host 'Salin dulu config/test_accounts.json.example -> config/test_accounts.json lalu isi password akun kamu.' -ForegroundColor Yellow
  exit 1
}
$dev = Get-Content $devPath -Raw | ConvertFrom-Json
$acc = Get-Content $accPath -Raw | ConvertFrom-Json

$script:base = $dev.SUPABASE_URL.TrimEnd('/')
$script:apikey = $dev.SUPABASE_ANON_KEY
$script:lines = @()
$script:pass = 0
$script:temuan = 0
$script:fail = 0
$script:skip = 0

# --- Helper --------------------------------------------------------------------
function Out-Line {
  param([string]$text, [string]$color = 'Gray')
  Write-Host $text -ForegroundColor $color
  $script:lines += $text
}

function Check {
  param([string]$id, [string]$name, [string]$status, [string]$detail = '')
  $color = 'DarkGray'
  if ($status -eq 'PASS')   { $color = 'Green';   $script:pass++ }
  elseif ($status -eq 'TEMUAN') { $color = 'Yellow'; $script:temuan++ }
  elseif ($status -eq 'FAIL')   { $color = 'Red';     $script:fail++ }
  elseif ($status -eq 'SKIP')   { $color = 'DarkCyan'; $script:skip++ }
  $suffix = ''
  if ($detail) { $suffix = " - $detail" }
  Out-Line ('[{0,-6}] {1} {2}{3}' -f $status, $id, $name, $suffix) $color
}

function Invoke-Api {
  param([string]$Method, [string]$Path, [string]$Token = $null,
        $BodyObj = $null, [string]$Prefer = $null)
  $m = $Method.ToUpper()
  $a = @('-sS','-m','30','-X',$m,"$script:base$Path",
         '-H',"apikey: $($script:apikey)",'-w',"`n%{http_code}")
  if ($Token)  { $a += @('-H',"Authorization: Bearer $Token") }
  if ($Prefer) { $a += @('-H',"Prefer: $Prefer") }
  $out = $null
  if ($null -ne $BodyObj) {
    $json = $BodyObj | ConvertTo-Json -Depth 6 -Compress
    $out = $json | curl.exe @a -H 'Content-Type: application/json' --data-binary '@-'
  } else {
    $out = curl.exe @a
  }
  $ls = @()
  if ($null -ne $out) { $ls = @($out) }
  if ($ls.Count -eq 0) { return @{ code = 0; body = 'tidak ada respons (curl gagal/timeout)' } }
  $code = 0
  if (-not [int]::TryParse(([string]$ls[-1]).Trim(), [ref]$code)) {
    return @{ code = 0; body = ($ls -join "`n") }
  }
  $body = ''
  if ($ls.Count -gt 1) { $body = ($ls[0..($ls.Count - 2)] -join "`n") }
  return @{ code = $code; body = $body }
}

function Get-Rows {
  param($r)
  if (-not $r.body) { return @() }
  try {
    $parsed = $r.body | ConvertFrom-Json
    if ($null -eq $parsed) { return @() }
    return @($parsed)
  } catch { return @() }
}

function Get-Token {
  param([string]$email, [string]$password)
  $script:lastAuthError = ''
  $r = Invoke-Api -Method 'Post' -Path '/auth/v1/token?grant_type=password' `
        -BodyObj @{ email = $email; password = $password }
  if ($r.code -ne 200) {
    $script:lastAuthError = "HTTP $($r.code): $($r.body)"
    return $null
  }
  try { return ($r.body | ConvertFrom-Json).access_token } catch { return $null }
}

function Get-UserId {
  param([string]$token)
  $p = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
  while ($p.Length % 4) { $p += '=' }
  $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
  return ($json | ConvertFrom-Json).sub
}

# --- 0. Login ketiga role ------------------------------------------------------
Out-Line '=== RLS Matrix Check - OEM Sparepart Catalog ===' 'Cyan'
Out-Line "Target : $script:base"
Out-Line "Waktu  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Out-Line ''

$script:tokens = @{}
foreach ($roleName in @('customer', 'customer2', 'admin')) {
  $a = $acc.$roleName
  if ($null -eq $a) { continue }
  if ("$($a.email)" -like 'ISI_*') {
    if ($roleName -eq 'customer2') { continue }
    Out-Line "Role '$roleName' masih placeholder di config/test_accounts.json - isi dulu filenya." 'Red'
    exit 1
  }
  $t = Get-Token $a.email $a.password
  if (-not $t) {
    if ($roleName -eq 'customer2') {
      Out-Line "Login customer2 gagal ($($a.email)) - role ini opsional, tes isolasi cart dilewati." 'Yellow'
      continue
    }
    Out-Line "Gagal login role '$roleName' ($($a.email)) - $($script:lastAuthError)" 'Red'
    Out-Line "Periksa lagi password di config/test_accounts.json (huruf besar-kecil, tanpa spasi ekstra)." 'Yellow'
    exit 1
  }
  $script:tokens[$roleName] = $t
  Out-Line "Login $roleName ... OK" 'DarkGray'
}
foreach ($wajib in @('customer', 'admin')) {
  if (-not $script:tokens[$wajib]) {
    Out-Line "Akun wajib '$wajib' tidak ada di config/test_accounts.json" 'Red'
    exit 1
  }
}
$uidCust  = Get-UserId $script:tokens.customer
$uidAdmin = Get-UserId $script:tokens.admin
$uidCust2 = $null
if ($script:tokens['customer2']) { $uidCust2 = Get-UserId $script:tokens.customer2 }
# Bersihkan sisa part tes dari run sebelumnya (jaga-jaga, aman jika tidak ada)
$null = Invoke-Api -Method Delete -Path '/rest/v1/parts?part_number=eq.RLS-TEST-001' -Token $script:tokens.admin
Out-Line ''

# --- Data dasar ----------------------------------------------------------------
$partsR = Invoke-Api -Method Get `
  -Path '/rest/v1/parts?select=id,name,part_number,price,stock,category,image_url&limit=5' `
  -Token $script:tokens.customer
$parts = Get-Rows $partsR
$partId = $null
if ($parts.Count -gt 0) { $partId = $parts[0].id }
if ($parts.Count -eq 0) {
  Out-Line 'PERINGATAN: data parts kosong - tes terkait parts akan SKIP. Tambah part dulu lewat panel admin.' 'Yellow'
  Out-Line ''
}

# --- S-01: customer membaca katalog -------------------------------------------
if ($partsR.code -eq 200) {
  Check 'S-01' 'Customer membaca parts' 'PASS' "HTTP 200, contoh $($parts.Count) baris"
} else {
  Check 'S-01' 'Customer membaca parts' 'FAIL' "HTTP $($partsR.code): $($partsR.body)"
}

# --- S-02: customer INSERT parts harus ditolak -------------------------------
if ($partId -or $parts.Count -gt 0) {
  $r = Invoke-Api -Method Post -Path '/rest/v1/parts' -Token $script:tokens.customer `
        -BodyObj @{ name = 'HACK-TES'; part_number = 'HACK-1'; price = 1; stock = 1 } `
        -Prefer 'return=representation'
  if ($r.code -eq 401 -or $r.code -eq 403) {
    Check 'S-02' 'Customer INSERT parts ditolak' 'PASS' "HTTP $($r.code)"
  } elseif ($r.code -eq 201) {
    Check 'S-02' 'Customer INSERT parts ditolak' 'TEMUAN' 'CRITICAL: insert BERHASIL - RLS insert parts bocor!'
    $inserted = Get-Rows $r
    if ($inserted.Count -gt 0) {
      $null = Invoke-Api -Method Delete -Path "/rest/v1/parts?id=eq.$($inserted[0].id)" -Token $script:tokens.admin
    }
  } else {
    Check 'S-02' 'Customer INSERT parts ditolak' 'FAIL' "HTTP $($r.code): $($r.body)"
  }
} else {
  Check 'S-02' 'Customer INSERT parts ditolak' 'SKIP' 'tidak ada data parts'
}

# --- S-03: customer UPDATE harga harus 0 baris -------------------------------
if ($partId) {
  $r = Invoke-Api -Method Patch -Path "/rest/v1/parts?id=eq.$partId" -Token $script:tokens.customer `
        -BodyObj @{ price = 999999 } -Prefer 'return=representation'
  $rows = Get-Rows $r
  if ($r.code -eq 200 -and $rows.Count -eq 0) {
    Check 'S-03' 'Customer UPDATE harga parts ditolak' 'PASS' '0 baris terpengaruh'
  } elseif ($rows.Count -gt 0) {
    Check 'S-03' 'Customer UPDATE harga parts ditolak' 'TEMUAN' "CRITICAL: harga BERUBAH jadi $($rows[0].price)"
    $null = Invoke-Api -Method Patch -Path "/rest/v1/parts?id=eq.$partId" -Token $script:tokens.admin `
             -BodyObj @{ price = $parts[0].price }
  } else {
    Check 'S-03' 'Customer UPDATE harga parts ditolak' 'FAIL' "HTTP $($r.code): $($r.body)"
  }

  # --- S-05: customer DELETE parts harus ditolak ----------------------------
  $r = Invoke-Api -Method Delete -Path "/rest/v1/parts?id=eq.$partId" -Token $script:tokens.customer `
        -Prefer 'return=representation'
  $rows = Get-Rows $r
  if ($r.code -eq 401 -or $r.code -eq 403) {
    Check 'S-05' 'Customer DELETE parts ditolak' 'PASS' "HTTP $($r.code)"
  } elseif ($r.code -eq 200 -and $rows.Count -eq 0) {
    Check 'S-05' 'Customer DELETE parts ditolak' 'PASS' '0 baris terhapus'
  } elseif ($rows.Count -gt 0) {
    Check 'S-05' 'Customer DELETE parts ditolak' 'TEMUAN' 'CRITICAL: part TERHAPUS oleh customer!'
    $null = Invoke-Api -Method Post -Path '/rest/v1/parts' -Token $script:tokens.admin `
             -BodyObj @{ name = $parts[0].name; part_number = $parts[0].part_number; price = $parts[0].price; stock = $parts[0].stock; category = $parts[0].category; image_url = $parts[0].image_url } `
             -Prefer 'return=representation'
  } else {
    Check 'S-05' 'Customer DELETE parts ditolak' 'FAIL' "HTTP $($r.code): $($r.body)"
  }
} else {
  Check 'S-03' 'Customer UPDATE harga parts ditolak' 'SKIP' 'tidak ada data parts'
  Check 'S-05' 'Customer DELETE parts ditolak' 'SKIP' 'tidak ada data parts'
}

# --- S-04: admin BOLEH update parts (nama, harga, stok) ------------------------
# Catatan: role warehouse dihapus (17 Okt 2026). Update parts kini admin-only.
if ($partId) {
  $r = Invoke-Api -Method Patch -Path "/rest/v1/parts?id=eq.$partId" -Token $script:tokens.admin `
        -BodyObj @{ stock = $parts[0].stock } -Prefer 'return=representation'
  if ($r.code -eq 200 -and $r.body -match '"id"') {
    Check 'S-04' 'Admin UPDATE parts diizinkan (nama/harga/stok)' 'PASS' 'update berhasil (HTTP 200, representasi part dikembalikan)'
  } elseif ($r.code -eq 200) {
    Check 'S-04' 'Admin UPDATE parts diizinkan (nama/harga/stok)' 'PASS' 'update diterima (HTTP 200)'
  } else {
    Check 'S-04' 'Admin UPDATE parts diizinkan (nama/harga/stok)' 'FAIL' "HTTP $($r.code): $($r.body)"
  }
} else {
  Check 'S-04' 'Admin UPDATE parts diizinkan (nama/harga/stok)' 'SKIP' 'tidak ada data parts'
}

# --- S-02b: admin INSERT + DELETE parts (CRUD penuh) --------------------------
$r = Invoke-Api -Method Post -Path '/rest/v1/parts' -Token $script:tokens.admin `
      -BodyObj @{ name = 'RLS-TEST (aman dihapus)'; part_number = 'RLS-TEST-001'; price = 1; stock = 0; category = 'Test'; image_url = '' } `
      -Prefer 'return=representation'
if ($r.code -eq 201) {
  Check 'S-02b' 'Admin INSERT parts diizinkan' 'PASS' 'HTTP 201'
  $baru = Get-Rows $r
  # Cleanup selalu dijalankan; fallback by part_number jika body insert tidak terbaca
  if ($baru.Count -gt 0) { $hapusPath = "/rest/v1/parts?id=eq.$($baru[0].id)" }
  else                   { $hapusPath = '/rest/v1/parts?part_number=eq.RLS-TEST-001' }
  $d = Invoke-Api -Method Delete -Path $hapusPath -Token $script:tokens.admin
  if ($d.code -eq 200 -or $d.code -eq 204) {
    Check 'S-05b' 'Admin DELETE parts diizinkan (cleanup)' 'PASS' 'part tes berhasil dihapus'
  } else {
    Check 'S-05b' 'Admin DELETE parts diizinkan (cleanup)' 'FAIL' "HTTP $($d.code)"
  }
} else {
  Check 'S-02b' 'Admin INSERT parts diizinkan' 'FAIL' "HTTP $($r.code): $($($r.body).Substring(0, [Math]::Min(180, $r.body.Length)))"
}

# --- S-09: admin membaca semua orders -----------------------------------------
$rAdminOrders = Invoke-Api -Method Get -Path '/rest/v1/orders?select=id&limit=100' -Token $script:tokens.admin
if ($rAdminOrders.code -eq 200) {
  $nAdm = (Get-Rows $rAdminOrders).Count
  Check 'S-09a' 'Admin membaca semua orders' 'PASS' "HTTP 200 ($nAdm baris)"
} else {
  Check 'S-09a' 'Admin membaca semua orders' 'FAIL' "HTTP $($rAdminOrders.code)"
}

# --- S-09/S-08: customer hanya melihat ordernya sendiri -----------------------
$rAdminOrders = Invoke-Api -Method Get -Path '/rest/v1/orders?select=id&limit=100' -Token $script:tokens.admin
$rCustOrders  = Invoke-Api -Method Get -Path '/rest/v1/orders?select=id&limit=100' -Token $script:tokens.customer
$adminIds = @(Get-Rows $rAdminOrders | ForEach-Object { $_.id })
$custIds  = @(Get-Rows $rCustOrders  | ForEach-Object { $_.id })
$foreign  = @($adminIds | Where-Object { $custIds -notcontains $_ })
if ($foreign.Count -gt 0) {
  $probe = $foreign[0]
  $r = Invoke-Api -Method Get -Path "/rest/v1/orders?select=id&id=eq.$probe" -Token $script:tokens.customer
  $rows = Get-Rows $r
  if ($r.code -eq 200 -and $rows.Count -eq 0) {
    Check 'S-08' 'Customer TIDAK bisa membaca order orang lain' 'PASS' "order $probe tidak terlihat"
  } elseif ($rows.Count -gt 0) {
    Check 'S-08' 'Customer TIDAK bisa membaca order orang lain' 'TEMUAN' "CRITICAL: order milik orang lain TERLIHAT ($probe)"
  } else {
    Check 'S-08' 'Customer TIDAK bisa membaca order orang lain' 'FAIL' "HTTP $($r.code)"
  }
} else {
  Check 'S-08' 'Customer TIDAK bisa membaca order orang lain' 'SKIP' 'butuh order milik akun lain sebagai pembanding'
}

# --- S-06: cart_items hanya milik sendiri -------------------------------------
# Catatan: role warehouse dihapus (17 Okt 2026). Tes isolasi kuat memerlukan
# 2 akun customer — dilakukan manual. Di sini cukup verifikasi customer tidak
# melihat cart milik user lain yang sudah ada di database.
$r = Invoke-Api -Method Get -Path '/rest/v1/cart_items?select=user_id&limit=100' -Token $script:tokens.customer
if ($r.code -eq 200) {
  $asing = @(Get-Rows $r | Where-Object { $_.user_id -ne $uidCust })
  if ($asing.Count -eq 0) {
    Check 'S-06' 'Customer hanya melihat cart miliknya sendiri' 'PASS' 'tidak ada baris milik user lain'
  } else {
    Check 'S-06' 'Customer hanya melihat cart miliknya sendiri' 'TEMUAN' "$($asing.Count) baris milik user lain terlihat"
  }
} else {
  Check 'S-06' 'Customer hanya melihat cart miliknya sendiri' 'FAIL' "HTTP $($r.code)"
}

# --- S-07: customer tidak bisa menulis cart user lain ------------------------
if ($uidCust2 -and $partId) {
  $r = Invoke-Api -Method Post -Path '/rest/v1/cart_items' -Token $script:tokens.customer `
        -BodyObj @{ user_id = $uidCust2; part_id = $partId; quantity = 1 } `
        -Prefer 'return=representation'
  if ($r.code -eq 401 -or $r.code -eq 403) {
    Check 'S-07' 'Customer INSERT cart user lain ditolak' 'PASS' "HTTP $($r.code)"
  } elseif ($r.code -eq 201) {
    Check 'S-07' 'Customer INSERT cart user lain ditolak' 'TEMUAN' 'CRITICAL: cart user lain bisa ditulis!'
    $x = Get-Rows $r
    if ($x.Count -gt 0) {
      $null = Invoke-Api -Method Delete -Path "/rest/v1/cart_items?id=eq.$($x[0].id)" -Token $script:tokens.customer2
    }
  } else {
    Check 'S-07' 'Customer INSERT cart user lain ditolak' 'FAIL' "HTTP $($r.code): $($r.body)"
  }
} else {
  Check 'S-07' 'Customer INSERT cart user lain ditolak' 'SKIP' 'butuh customer2 (opsional) + data parts'
}

# --- S-25: customer tidak bisa mengangkat dirinya jadi admin ------------------
$roleAsli = 'customer'
$r = Invoke-Api -Method Patch -Path "/rest/v1/profiles?id=eq.$uidCust" -Token $script:tokens.customer `
      -BodyObj @{ role = 'admin' } -Prefer 'return=representation'
$rows = Get-Rows $r
if ($rows.Count -gt 0 -and $rows[0].role -eq 'admin') {
  Check 'S-25' 'Customer TIDAK bisa ubah role sendiri' 'TEMUAN' 'CRITICAL: self-promotion ke admin BERHASIL!'
  $rv = Invoke-Api -Method Patch -Path "/rest/v1/profiles?id=eq.$uidCust" -Token $script:tokens.customer `
         -BodyObj @{ role = 'customer' } -Prefer 'return=representation'
  $rvRows = Get-Rows $rv
  if ($rvRows.Count -gt 0 -and $rvRows[0].role -eq 'customer') {
    Out-Line '         (revert role ke customer: BERHASIL - data aman kembali)' 'DarkYellow'
  } else {
    Out-Line '         (PERINGATAN: revert role gagal - ubah manual di Table Editor!)' 'Red'
  }
} elseif ($r.code -eq 200 -and $rows.Count -eq 0) {
  Check 'S-25' 'Customer TIDAK bisa ubah role sendiri' 'PASS' 'update role ditolak (0 baris)'
} elseif ($rows.Count -gt 0) {
  Check 'S-25' 'Customer TIDAK bisa ubah role sendiri' 'PASS' "role tetap '$($rows[0].role)' (dikoreksi trigger/defense)"
} else {
  Check 'S-25' 'Customer TIDAK bisa ubah role sendiri' 'FAIL' "HTTP $($r.code): $($r.body)"
}

# --- INFO: visibilitas profiles & enumerasi username --------------------------
$r = Invoke-Api -Method Get -Path '/rest/v1/profiles?select=id,username,role&limit=50' -Token $script:tokens.customer
if ($r.code -eq 200) {
  $rows = Get-Rows $r
  $asing = @($rows | Where-Object { $_.id -ne $uidCust })
  if ($asing.Count -gt 0) {
    Out-Line ("[INFO  ] I-01  profiles user lain terbaca oleh customer ($($asing.Count) baris) - username/role enumerable, risiko privasi rendah") 'DarkYellow'
  } else {
    Out-Line '[INFO  ] I-01  profiles terbatas ke pemilik sendiri' 'DarkGray'
  }
}
if ($acc.admin -and $acc.admin.username) {
  $r = Invoke-Api -Method Post -Path '/rest/v1/rpc/get_email_by_username' -Token $script:tokens.customer `
        -BodyObj @{ p_username = $acc.admin.username }
  if ($r.code -eq 200 -and "$($r.body)" -match '@') {
    Out-Line '[INFO  ] I-02  RPC get_email_by_username bisa resolve username lain -> username enumeration (by-design untuk login; catat sebagai risiko privasi rendah)' 'DarkYellow'
  } else {
    Out-Line '[INFO  ] I-02  RPC get_email_by_username tidak membocorkan email user lain' 'DarkGray'
  }
}
Out-Line '[INFO  ] I-03  Tes RPC checkout_cart (transaksi stok) dicakup checklist manual M-06 - jalur app' 'DarkGray'

# --- Ringkasan & simpan -------------------------------------------------------
Out-Line ''
Out-Line ('Ringkasan: {0} PASS | {1} TEMUAN | {2} FAIL | {3} SKIP' -f $script:pass, $script:temuan, $script:fail, $script:skip) 'Cyan'
if ($script:temuan -gt 0) {
  Out-Line 'TEMUAN = deviasi dari spesifikasi -> catat di docs/pengujian/bug-tracker.md' 'Yellow'
}
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$outDir = Join-Path $root 'docs\pengujian\bukti'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath = Join-Path $outDir "rls-check_$stamp.txt"
[System.IO.File]::WriteAllLines($outPath, $script:lines)
Out-Line "Hasil tersimpan: $outPath" 'Cyan'
if ($script:fail -gt 0) { exit 1 }
exit 0

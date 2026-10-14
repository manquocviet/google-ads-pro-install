# Cai Google Ads Pro tren Windows bang mot lenh (dan vao Command Prompt). Lenh do nguoi quan ly tao bang tools/invite.py:
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/manquocviet/google-ads-pro-install/main/install.ps1))) 'gap1...'"
# Ma moi gap1... chua dia chi repo va mot khoa chi doc rieng cho nguoi nay (thu hoi duoc). Ban cu dung token van chay:
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "& {param($t) & ([scriptblock]::Create((irm https://api.github.com/repos/manquocviet/google-ads-pro/contents/install.ps1 -Headers @{Authorization='Bearer '+$t;Accept='application/vnd.github.raw'}))) $t} TOKEN"
# Thieu Git hoac Python thi tu tai va cai, roi tai tool ve %USERPROFILE%\google-ads-pro, tao icon tren Desktop va mo tool.
param([string]$Code = "")
$ErrorActionPreference = "Continue"  # loi tu git/py tu xu ly ben duoi
$ProgressPreference = "SilentlyContinue"  # tai file nhanh hon nhieu tren PowerShell 5
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Repo = "manquocviet/google-ads-pro"
$Dir = Join-Path $env:USERPROFILE "google-ads-pro"
$Key = Join-Path $env:USERPROFILE ".ssh\google_ads_pro_ed25519"
# Duong dan khoa dung dau / va dat trong ngoac kep de git (sh) doc dung khi ten user co dau cach
$SshCmd = 'ssh -i "' + ($Key -replace '\\', '/') + '" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15'

function Say($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host ""; Write-Host "LOI: $m" -ForegroundColor Red; Read-Host "Nhan Enter de dong"; exit 1 }
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Has-Python {
  # Bo qua "python" gia cua Microsoft Store (chi mo Store, khong chay duoc)
  if (Has "py") { try { $v = & py -3 --version 2>$null; if ("$v" -match "Python 3") { return $true } } catch {} }
  if (Has "python") { try { $v = & python --version 2>$null; if ("$v" -match "Python 3") { return $true } } catch {} }
  return $false
}
function Winget-Install($id) {
  if (-not (Has "winget")) { return }
  & winget install -e --id $id --silent --accept-source-agreements --accept-package-agreements
  Refresh-Path
}
function Download($url, $name) {
  $f = Join-Path $env:TEMP $name
  Invoke-WebRequest -UseBasicParsing $url -OutFile $f -ErrorAction Stop
  return $f
}

if (-not $Code) { Fail "Thieu ma moi. Dan nguyen dong lenh nguoi gui tool dua cho ban (dong ket thuc bang ma gap1...)." }

# 1. Git
if (-not (Has "git")) {
  Say "Dang cai Git (1-3 phut)..."
  Winget-Install "Git.Git"
  if (-not (Has "git")) {
    try {
      $rel = Invoke-RestMethod -UseBasicParsing "https://api.github.com/repos/git-for-windows/git/releases/latest" -ErrorAction Stop
      $asset = $rel.assets | Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1
      $f = Download $asset.browser_download_url "git-setup.exe"
    } catch { Fail "Khong tai duoc bo cai Git. Tai tay tai https://git-scm.com/download/win roi chay lai lenh." }
    Start-Process $f -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES" -Wait
    Refresh-Path
    if (-not (Has "git")) { $env:Path += ";C:\Program Files\Git\cmd" }
  }
  if (-not (Has "git")) { Fail "Cai Git khong thanh cong. Tai tay tai https://git-scm.com/download/win roi chay lai lenh." }
}

# 2. Python
if (-not (Has-Python)) {
  Say "Dang cai Python (1-3 phut)..."
  Winget-Install "Python.Python.3.12"
  if (-not (Has-Python)) {
    try { $f = Download "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe" "python-setup.exe" }
    catch { Fail "Khong tai duoc bo cai Python. Tai tay tai https://www.python.org/downloads/ (tick 'Add python.exe to PATH') roi chay lai lenh." }
    Start-Process $f -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_launcher=1" -Wait
    Refresh-Path
  }
  if (-not (Has-Python)) { Fail "Cai Python khong thanh cong. Tai tay tai https://www.python.org/downloads/ (tick 'Add python.exe to PATH') roi chay lai lenh." }
}

# 3. Ma moi: luu khoa chi doc cua may nay, git dung khoa do de tai va cap nhat tool
$env:GIT_TERMINAL_PROMPT = "0"
$Invite = $Code.Trim().StartsWith("gap1.")
if ($Invite) {
  try {
    $b = $Code.Trim().Substring(5).Replace('-', '+').Replace('_', '/')
    $b += "=" * ((4 - $b.Length % 4) % 4)
    $inv = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b)) | ConvertFrom-Json
    if (-not $inv.remote -or "$($inv.key)" -notmatch "OPENSSH PRIVATE KEY") { throw "thieu" }
  } catch { Fail "Ma moi khong dung. Copy lai nguyen dong lenh nguoi gui dua (khong thieu ky tu) roi chay lai." }
  New-Item -ItemType Directory -Force (Split-Path $Key) | Out-Null
  $old = if (Test-Path $Key) { [IO.File]::ReadAllText($Key) } else { $null }
  $k = "$($inv.key)".Replace("`r", "")
  if (-not $k.EndsWith("`n")) { $k += "`n" }
  [IO.File]::WriteAllText($Key, $k, (New-Object Text.UTF8Encoding($false)))
  $url = $inv.remote
  $env:GIT_SSH_COMMAND = $SshCmd
  & git ls-remote -q $url 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    if ($old) { [IO.File]::WriteAllText($Key, $old, (New-Object Text.UTF8Encoding($false))) }
    Fail "Ma moi chua dung duoc (da bi thu hoi, hoac mang/GitHub dang loi). Thu lai sau it phut; van loi thi nho nguoi gui tao ma moi."
  }
} else {
  $url = "https://x-access-token:$Code@github.com/$Repo.git"  # cach cu: token GitHub
}

# 4. Tai tool (da co thi chi cap nhat)
if (Test-Path (Join-Path $Dir ".git")) {
  Say "Da co tool tai $Dir, dang cap nhat..."
  & git -C $Dir remote set-url origin $url
  if ($Invite) { & git -C $Dir config core.sshCommand $SshCmd }
  & git -C $Dir pull --ff-only -q
} else {
  Say "Dang tai Google Ads Pro ve $Dir ..."
  & git clone -q $url $Dir
  if ($LASTEXITCODE -ne 0) { Fail "Khong tai duoc tool. Kiem tra lai ma moi (co the da bi thu hoi) va mang." }
  if ($Invite) { & git -C $Dir config core.sshCommand $SshCmd }
}

# 5. Icon tren Desktop
try {
  $desk = [Environment]::GetFolderPath("Desktop")
  $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desk "Google Ads Pro.lnk"))
  $sc.TargetPath = Join-Path $Dir "start.bat"
  $sc.WorkingDirectory = $Dir
  $sc.Description = "Google Ads Pro"
  $sc.Save()
  Say "Da tao icon 'Google Ads Pro' tren Desktop. Lan sau bam dup icon do de mo tool."
} catch { Say "Khong tao duoc icon tren Desktop; mo tool bang file start.bat trong $Dir" }

# 6. Mo tool (lan dau cai thu vien 1-2 phut)
Say "Dang mo tool, lan dau can 1-2 phut de cai thu vien..."
Start-Process -FilePath (Join-Path $Dir "start.bat") -WorkingDirectory $Dir

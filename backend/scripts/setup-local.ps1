$ErrorActionPreference = 'Stop'
$pgBin = 'C:\src\postgresql\pgsql\bin'
$dataDir = & (Join-Path $PSScriptRoot 'resolve-data-dir.ps1')
$clusterDir = Join-Path $dataDir 'postgres-data'
$passwordFile = Join-Path $dataDir '.init-password'
$appSecretFile = Join-Path $dataDir 'backend.env'
$adminSecretFile = Join-Path $dataDir 'postgres-admin.env'

if (-not (Test-Path (Join-Path $pgBin 'initdb.exe'))) {
  throw 'PostgreSQL não encontrado em C:\src\postgresql\pgsql\bin.'
}
if (Test-Path $clusterDir) {
  throw 'O banco já existe. Não execute a inicialização novamente.'
}

function Restrict-Access([string]$path, [bool]$directory) {
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $grant = if ($directory) { "*$($sid):(OI)(CI)F" } else { "*$($sid):F" }
  & icacls.exe $path /inheritance:r /grant:r $grant | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Falha ao restringir acesso a $path" }
}

New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
Restrict-Access $dataDir $true
$adminPassword = [Convert]::ToBase64String(
  [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)) -replace '[/+=]', 'A'
$appPassword = [Convert]::ToBase64String(
  [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)) -replace '[/+=]', 'B'
[System.IO.File]::WriteAllText($passwordFile, $adminPassword)
Restrict-Access $passwordFile $false
try {
  & (Join-Path $pgBin 'initdb.exe') -D $clusterDir -U fisio_owner -A scram-sha-256 --encoding=UTF8 "--pwfile=$passwordFile" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao inicializar PostgreSQL.' }
} finally {
  Remove-Item -LiteralPath $passwordFile -ErrorAction SilentlyContinue
}
Restrict-Access $clusterDir $true
& (Join-Path $pgBin 'pg_ctl.exe') -D $clusterDir -l (Join-Path $dataDir 'postgres.log') -o '-h 127.0.0.1 -p 5433' start
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar PostgreSQL.' }

$env:PGPASSWORD = $adminPassword
try {
  @(
    "CREATE ROLE fisio_app LOGIN PASSWORD '$appPassword';"
    'CREATE DATABASE fisio360 OWNER fisio_app;'
  ) | & (Join-Path $pgBin 'psql.exe') -h 127.0.0.1 -p 5433 -U fisio_owner -d postgres -v ON_ERROR_STOP=1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar banco e usuário.' }
} finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

[System.IO.File]::WriteAllText($appSecretFile,
  "postgresql://fisio_app:$appPassword@127.0.0.1:5433/fisio360")
[System.IO.File]::WriteAllText($adminSecretFile,
  "postgresql://fisio_owner:$adminPassword@127.0.0.1:5433/postgres")
Restrict-Access $appSecretFile $false
Restrict-Access $adminSecretFile $false
Write-Output 'PostgreSQL local iniciado. Credenciais guardadas em AppData\Local\Fisio360.'

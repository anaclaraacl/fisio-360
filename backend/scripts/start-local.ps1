$ErrorActionPreference = 'Stop'
$pgCtl = 'C:\src\postgresql\pgsql\bin\pg_ctl.exe'
$dataDir = & (Join-Path $PSScriptRoot 'resolve-data-dir.ps1')
& $pgCtl -D (Join-Path $dataDir 'postgres-data') -l (Join-Path $dataDir 'postgres.log') -o '-h 127.0.0.1 -p 5433' start
if ($LASTEXITCODE -ne 0) { throw 'Falha ao iniciar PostgreSQL.' }

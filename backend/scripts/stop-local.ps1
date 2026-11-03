$ErrorActionPreference = 'Stop'
$dataDir = & (Join-Path $PSScriptRoot 'resolve-data-dir.ps1')
& 'C:\src\postgresql\pgsql\bin\pg_ctl.exe' -D (Join-Path $dataDir 'postgres-data') stop -m fast
if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar PostgreSQL.' }

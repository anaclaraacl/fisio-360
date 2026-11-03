$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratchRoot = 'C:\jtmp'
$scratch = Join-Path $scratchRoot ("fisio360-package-" + [guid]::NewGuid().ToString('N'))
$bundle = Join-Path $scratch 'Fisio360'
New-Item -ItemType Directory -Path $bundle -Force | Out-Null
try {
  foreach ($folder in @('lib', 'assets', 'docs', '.vscode')) {
    Copy-Item -LiteralPath (Join-Path $project $folder) -Destination $bundle -Recurse
  }
  foreach ($file in @('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.metadata', '.gitignore', 'README.md', 'Iniciar Fisio 360.cmd')) {
    Copy-Item -LiteralPath (Join-Path $project $file) -Destination $bundle
  }
  & robocopy.exe (Join-Path $project 'android') (Join-Path $bundle 'android') /E `
    /XD .gradle .kotlin build /XF local.properties | Out-Null
  if ($LASTEXITCODE -ge 8) { throw 'Falha ao copiar Android.' }
  $backend = Join-Path $bundle 'backend'
  New-Item -ItemType Directory -Path $backend | Out-Null
  foreach ($folder in @('src', 'sql', 'scripts')) {
    Copy-Item -LiteralPath (Join-Path $project "backend\$folder") -Destination $backend -Recurse
  }
  foreach ($file in @('package.json', 'package-lock.json', 'tsconfig.json', '.env.example')) {
    Copy-Item -LiteralPath (Join-Path $project "backend\$file") -Destination $backend
  }
  $output = Join-Path $project 'dist\Fisio360-backend-fonte.zip'
  & tar.exe -a -cf $output -C $scratch Fisio360
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar ZIP.' }
  Write-Output "Código-fonte empacotado: $output"
} finally {
  $resolved = [System.IO.Path]::GetFullPath($scratch)
  if ($resolved.StartsWith("$scratchRoot\fisio360-package-", [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}

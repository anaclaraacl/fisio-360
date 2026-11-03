# Mantém a configuração na conta real mesmo quando LOCALAPPDATA é redirecionado.
if ($env:FISIO_DATA_DIR) { return $env:FISIO_DATA_DIR }
$profileDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath('UserProfile') }
$profileDataDir = Join-Path $profileDir 'AppData\Local\Fisio360'
if (Test-Path -LiteralPath (Join-Path $profileDataDir 'backend.env')) { return $profileDataDir }
$codexDataDir = Join-Path $profileDir 'AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Fisio360'
if (Test-Path -LiteralPath (Join-Path $codexDataDir 'backend.env')) { return $codexDataDir }
if ($env:LOCALAPPDATA) {
  $localDataDir = Join-Path $env:LOCALAPPDATA 'Fisio360'
  if (Test-Path -LiteralPath (Join-Path $localDataDir 'backend.env')) { return $localDataDir }
}
return $profileDataDir

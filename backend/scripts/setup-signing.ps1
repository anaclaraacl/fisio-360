$ErrorActionPreference = 'Stop'
$dataDir = & (Join-Path $PSScriptRoot 'resolve-data-dir.ps1')
$keyFile = Join-Path $dataDir 'android-release.p12'
$propertiesFile = Join-Path $dataDir 'android-signing.properties'
$keytool = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot\bin\keytool.exe'
if ((Test-Path $keyFile) -or (Test-Path $propertiesFile)) {
  throw 'A assinatura já existe. Não substitua a chave usada para atualizar o app.'
}
if (-not (Test-Path $keytool)) { throw 'JDK 17 não encontrado.' }
$secret = [Convert]::ToBase64String(
  [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(48)) -replace '[/+=]', 'C'
$env:FISIO_SIGN_PASSWORD = $secret
try {
  & $keytool -genkeypair -noprompt -storetype PKCS12 -keystore $keyFile `
    -alias fisio360 -keyalg RSA -keysize 3072 -validity 3650 `
    -dname 'CN=Fisio 360, O=Fisio 360, C=BR' `
    -storepass:env FISIO_SIGN_PASSWORD -keypass:env FISIO_SIGN_PASSWORD
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar a chave Android.' }
  @(
    "storeFile=$($keyFile.Replace('\', '\\'))"
    "storePassword=$secret"
    'keyAlias=fisio360'
    "keyPassword=$secret"
  ) | Set-Content -LiteralPath $propertiesFile -Encoding ascii
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  foreach ($path in @($keyFile, $propertiesFile)) {
    & icacls.exe $path /inheritance:r /grant:r "*$($sid):F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Falha ao proteger $path" }
  }
} finally {
  Remove-Item Env:FISIO_SIGN_PASSWORD -ErrorAction SilentlyContinue
}
Write-Output 'Chave Android criada no perfil privado. Faça uma cópia segura para futuras atualizações.'

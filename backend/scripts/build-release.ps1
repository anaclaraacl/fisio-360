param(
  [ValidateSet('release', 'debug')][string]$BuildType = 'release',
  [switch]$IncludePresentationCopy
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dataDir = & (Join-Path $PSScriptRoot 'resolve-data-dir.ps1')
$scratchRoot = 'C:\jtmp'
$scratchPrefix = "fisio360-$BuildType-"
$scratch = Join-Path $scratchRoot ($scratchPrefix + [guid]::NewGuid().ToString('N'))
if (-not $scratch.StartsWith("$scratchRoot\$scratchPrefix", [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Caminho temporário inesperado.'
}
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
  foreach ($folder in @('lib', 'assets')) {
    Copy-Item -LiteralPath (Join-Path $project $folder) -Destination $scratch -Recurse
  }
  foreach ($file in @('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', '.metadata')) {
    Copy-Item -LiteralPath (Join-Path $project $file) -Destination $scratch
  }
  & robocopy.exe (Join-Path $project 'android') (Join-Path $scratch 'android') /E `
    /XD .gradle .kotlin build /XF local.properties | Out-Null
  if ($LASTEXITCODE -ge 8) { throw 'Falha ao copiar o projeto Android.' }
  $env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot'
  $env:ANDROID_HOME = 'C:\src\android-sdk'
  $env:ANDROID_SDK_ROOT = 'C:\src\android-sdk'
  $env:TEMP = $scratchRoot
  $env:TMP = $scratchRoot
  $env:PUB_CACHE = Join-Path $scratchRoot 'pub-cache'
  if ($BuildType -eq 'release') {
    $temporaryKey = Join-Path $scratch 'android-release.p12'
    Copy-Item -LiteralPath (Join-Path $dataDir 'android-release.p12') `
      -Destination $temporaryKey
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $temporaryKey /inheritance:r /grant:r "*$($sid):F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao proteger chave temporária.' }
    $env:FISIO_SIGNING_KEY = $temporaryKey
  }
  Push-Location $scratch
  try {
    & 'C:\src\flutter\bin\flutter.bat' pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao obter dependências Flutter.' }
    & 'C:\src\flutter\bin\flutter.bat' build apk "--$BuildType"
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar APK.' }
  } finally { Pop-Location }
  $destination = Join-Path $project 'dist'
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $scratch "build\app\outputs\flutter-apk\app-$BuildType.apk") `
    -Destination (Join-Path $destination "Fisio360-$BuildType.apk") -Force
  Write-Output "APK $BuildType`: $destination\Fisio360-$BuildType.apk"
  if ($IncludePresentationCopy) {
    if ($BuildType -ne 'debug') { throw 'A cópia de apresentação só pode acompanhar o build debug.' }
    # Altera somente a cópia temporária. A sessão do app principal fica separada.
    $gradlePath = Join-Path $scratch 'android\app\build.gradle.kts'
    $gradleContent = [System.IO.File]::ReadAllText($gradlePath)
    $gradleContent = $gradleContent.Replace('applicationId = "com.example.fisio_360"', 'applicationId = "com.example.fisio_360.apresentacao"')
    [System.IO.File]::WriteAllText($gradlePath, $gradleContent)
    $manifestPath = Join-Path $scratch 'android\app\src\main\AndroidManifest.xml'
    $manifestContent = [System.IO.File]::ReadAllText($manifestPath).Replace('android:label="Fisio 360"', 'android:label="Fisio 360 Demo"')
    [System.IO.File]::WriteAllText($manifestPath, $manifestContent)
    Push-Location $scratch
    try {
      & 'C:\src\flutter\bin\flutter.bat' build apk --debug '--dart-define=FISIO_API_BASE_URL=https://10.0.2.2:8444'
      if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar a cópia de apresentação.' }
    } finally { Pop-Location }
    $captureDir = Join-Path $project 'apresentacao\.build'
    New-Item -ItemType Directory -Path $captureDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $scratch 'build\app\outputs\flutter-apk\app-debug.apk') `
      -Destination (Join-Path $captureDir 'Fisio360-capturas.apk') -Force
    Write-Output 'Cópia temporária para capturas preparada.'
  }
} finally {
  Remove-Item Env:FISIO_SIGNING_KEY -ErrorAction SilentlyContinue
  $resolved = [System.IO.Path]::GetFullPath($scratch)
  if ($resolved.StartsWith("$scratchRoot\$scratchPrefix", [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}

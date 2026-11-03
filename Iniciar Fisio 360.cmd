@echo off
setlocal
set "NODE=%ProgramFiles%\nodejs\node.exe"
if not exist "%NODE%" (
  echo Node.js nao foi encontrado em "%NODE%".
  pause
  exit /b 1
)
"%NODE%" "%~dp0backend\scripts\start-vscode.mjs"
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%

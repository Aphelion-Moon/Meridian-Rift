@echo off
setlocal
powershell.exe -NoLogo -NoProfile -File "%~dp0tools\dogmos\profile_server.ps1" %*
exit /b %ERRORLEVEL%

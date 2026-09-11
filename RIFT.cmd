@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "RIFT_NETWORK=%MERIDIAN_RIFT_BUILD_NETWORK%"
if not defined RIFT_NETWORK set "RIFT_NETWORK=offline"
call :detect_network %*
if errorlevel 1 exit /b %ERRORLEVEL%

if /I "%RIFT_NETWORK%"=="allow" (
	call "%~dp0tools\bootstrap\javascript.bat" "%~dp0tools\rift\rift.ts" %*
	exit /b %ERRORLEVEL%
)
if /I not "%RIFT_NETWORK%"=="offline" (
	>&2 echo [usage_error] network mode must be offline or allow
	exit /b 2
)

for /f "tokens=2 delims==" %%V in ('findstr /B /C:"export BUN_VERSION=" "%~dp0dependencies.sh"') do set "RIFT_BUN_VERSION=%%V"
if not defined RIFT_BUN_VERSION (
	>&2 echo [offline_preflight_failed] BUN_VERSION is missing
	exit /b 3
)
set "RIFT_CACHE=%TG_BOOTSTRAP_CACHE%"
if not defined RIFT_CACHE set "RIFT_CACHE=%~dp0tools\bootstrap\.cache"
set "RIFT_BUN=%RIFT_CACHE%\bun-v%RIFT_BUN_VERSION%-x64\bun.exe"
if not exist "%RIFT_BUN%" (
	>&2 echo [offline_preflight_failed] pinned Bun is absent
	exit /b 3
)
"%RIFT_BUN%" "%~dp0tools\rift\rift.ts" %*
exit /b %ERRORLEVEL%

:detect_network
if "%~1"=="" exit /b 0
if /I "%~1"=="--network" goto detect_network_value
if /I "%~1"=="--network=offline" set "RIFT_NETWORK=offline"
if /I "%~1"=="--network=allow" set "RIFT_NETWORK=allow"
shift
goto detect_network

:detect_network_value
shift
if "%~1"=="" exit /b 2
set "RIFT_NETWORK=%~1"
shift
goto detect_network

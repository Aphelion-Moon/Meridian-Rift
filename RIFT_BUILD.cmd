@echo off
setlocal EnableExtensions
if not "%~1"=="" (
	>&2 echo [usage_error] RIFT_BUILD.cmd does not accept arguments
	exit /b 2
)
if not defined MERIDIAN_RIFT_BUILD_NETWORK set "MERIDIAN_RIFT_BUILD_NETWORK=offline"
if /I not "%MERIDIAN_RIFT_BUILD_NETWORK%"=="offline" if /I not "%MERIDIAN_RIFT_BUILD_NETWORK%"=="allow" exit /b 2
if not defined MERIDIAN_RIFT_FORCE_REBUILD set "MERIDIAN_RIFT_FORCE_REBUILD=0"
if "%MERIDIAN_RIFT_FORCE_REBUILD%"=="1" (
	call "%~dp0RIFT.cmd" compile --mode full --force --format result
) else if "%MERIDIAN_RIFT_FORCE_REBUILD%"=="0" (
	call "%~dp0RIFT.cmd" compile --mode full --format result
) else (
	>&2 echo [usage_error] MERIDIAN_RIFT_FORCE_REBUILD must be 0 or 1
	exit /b 2
)
exit /b %ERRORLEVEL%

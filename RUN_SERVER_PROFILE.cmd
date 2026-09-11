@echo off
setlocal

set "tracy_marker=%~dp0data\enable_tracy"
type nul > "%tracy_marker%"
if errorlevel 1 (
	echo Failed to enable Tracy profiling at "%tracy_marker%".
	exit /b 1
)

echo Tracy profiling enabled for this server launch.
call "%~dp0RUN_SERVER.cmd" %*
set "server_exit=%ERRORLEVEL%"

if exist "%tracy_marker%" del /q "%tracy_marker%"
exit /b %server_exit%

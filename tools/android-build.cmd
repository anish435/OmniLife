@echo off
REM Usage: toolsndroid-build.cmd [debug] [release] [aab]
REM Runs the WSL build script (see docs\android-build-wsl.md).
set "SCRIPT=%~dp0android-build-wsl.sh"
set "MSYS_NO_PATHCONV=1"
for /f "usebackq delims=" %%i in (`wsl -d Ubuntu -u root -- wslpath -a "%SCRIPT%"`) do set "WSLSCRIPT=%%i"
wsl -d Ubuntu -u root -- bash "%WSLSCRIPT%" %*

@echo off
cd /d "%~dp0"
rem Smooth setting (default in this build; the line keeps it explicit).
set EDEN_CPU_WRITE_PAGES=1
rem High priority helps the emulator threads in busy scenes.
start "" /high "Fortune's Eden.exe"

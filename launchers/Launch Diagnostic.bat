@echo off
cd /d "%~dp0"
set EDEN_CPU_WRITE_PAGES=1
rem Performance statistics every 4 seconds in user\logden_log.txt (costs a little FPS).
set EDEN_BACK_THREAD_STATS=1
start "" /high "Fortune's Eden.exe"

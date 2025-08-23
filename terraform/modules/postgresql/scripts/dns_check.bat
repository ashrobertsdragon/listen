@echo off
set HOST=%1

for /L %%i in (1,1,20) do (
    nslookup %HOST% >nul 2>&1
    if %ERRORLEVEL%==0 (
        exit /b 0
    )
    timeout /t 30 /nobreak >nul
)

exit /b 1

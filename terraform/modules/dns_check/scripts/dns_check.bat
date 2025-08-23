@echo off
set HOST=%1

for /L %%i in (1,1,20) do (
    nslookup %HOST% >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo "Host ready"
        exit /b 0
    )
    echo "Host not yet ready. Waiting 30s"
    timeout /t 30 /nobreak >nul
)
echo "Host not ready after 10 minutes"
exit /b 1

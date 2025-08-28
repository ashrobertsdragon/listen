@echo off
set supabase_host_name=%1

for /L %%i in (1,1,20) do (
    nslookup %supabase_host_name% >nul 2>&1
    if %ERRORLEVEL%==0 (
        exit /b 0
    )
    timeout /t 30 /nobreak >nul
)
echo "Host not ready after 10 minutes"
exit /b 1

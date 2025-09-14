@echo off
curl "https://api.supabase.com/v1/projects/%1/database/query" ^
    -H "Authorization: Bearer %2" ^
    -H "Content-Type: application/json" ^
    -d "%~3" ^
    --fail ^
    --silent
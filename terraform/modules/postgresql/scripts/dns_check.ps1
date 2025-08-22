param([string]$supabase_rest_api_host)

for ($i = 1; $i -le 20; $i++) {
  Resolve-DnsName -Name $supabase_rest_api_host -ErrorAction SilentlyContinue | Out-Null
  if ($?) {
    exit 0
  }
  Start-Sleep -Seconds 30
}

exit 1

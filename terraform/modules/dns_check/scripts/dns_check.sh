#!/usr/bin/env bash
supabase_host_name="$1"
for i in {1..20}; do
  if nslookup $supabase_host_name >/dev/null 2>&1; then
    exit 0
  fi
  sleep 30
done
echo "Host not ready after 10 minutes"
exit 1
#!/usr/bin/env bash
supabase_rest_api_host="$1"
for i in {1..20}; do
  if nslookup $supabase_rest_api_host >/dev/null 2>&1; then
    exit 0
  fi
  sleep 30
done
exit 1
#!/bin/bash
# Copies the Groq key from a GitHub secret into Supabase (server side only).
if [ -z "$GROQ_API_KEY" ] || [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "Groq key or Supabase token not set in GitHub secrets - skipping."
  exit 0
fi
body=$(python3 -c 'import json,os;print(json.dumps([{"name":"GROQ_API_KEY","value":os.environ["GROQ_API_KEY"]}]))')
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "https://api.supabase.com/v1/projects/carzbtnhfkunhluqsxyf/secrets" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" -d "$body")
echo "Supabase answered: $code"
[ "$code" = "201" ] || [ "$code" = "200" ]

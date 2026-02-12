#!/usr/bin/env bash
# Outputs the next sequential tag number for a given date prefix (YYYYMMDD).
# Queries GitHub Container Registry API to list existing tags matching {date_prefix}.*
# and returns max(existing numbers) + 1, or 1 if none exist.
#
# Usage: get-next-tag-number.sh <owner> <package_name> <date_prefix> [token]
#   owner:        GitHub org or user (e.g. from github.repository_owner)
#   package_name: Container package name (e.g. bluefin-dx-macintel)
#   date_prefix:  Date in YYYYMMDD format (e.g. 20260212)
#   token:        Optional; defaults to GITHUB_TOKEN env var.
#
# Output: single integer (e.g. 1 or 3)
set -euo pipefail

OWNER="${1:?Missing owner}"
PACKAGE_NAME="${2:?Missing package_name}"
DATE_PREFIX="${3:?Missing date_prefix}"
TOKEN="${4:-${GITHUB_TOKEN:-}}"

if [[ -z "$TOKEN" ]]; then
  echo "Error: GITHUB_TOKEN must be set or passed as 4th argument" >&2
  exit 1
fi

# List package versions: GET /orgs/{org}/packages/container/{name}/versions
# Each version has a "name" field (the tag) and optionally metadata.container_tags.
# Try org first; if 404, try user endpoint (user-owned repos).
url_org="https://api.github.com/orgs/${OWNER}/packages/container/${PACKAGE_NAME}/versions"
url_user="https://api.github.com/user/packages/container/${PACKAGE_NAME}/versions"

resp=$(curl -sS -w "\n%{http_code}" -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$url_org?per_page=100") || true
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [[ "$http_code" == "404" ]]; then
  resp=$(curl -sS -w "\n%{http_code}" -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url_user?per_page=100") || true
  http_code=$(echo "$resp" | tail -n1)
  body=$(echo "$resp" | sed '$d')
fi

if [[ "$http_code" != "200" ]]; then
  # Package may not exist yet (first build)
  echo 1
  exit 0
fi

# Collect all tag names: version "name" is the primary tag; metadata.container_tags may list more
max_num=0
while read -r tag; do
  if [[ -n "$tag" ]] && [[ "$tag" =~ ^${DATE_PREFIX}\.(.+)$ ]]; then
    num="${BASH_REMATCH[1]}"
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -gt "$max_num" ]]; then
      max_num="$num"
    fi
  fi
done < <(echo "$body" | jq -r '.[] | .name // empty, (.metadata.container_tags[]? // empty)')

echo $((max_num + 1))

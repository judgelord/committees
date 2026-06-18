#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/unitedstates/congress-legislators.git"
REPO_DIR="congress-legislators"
FILE_PATH="committee-membership-current.yaml"
OUT_DIR="committee-membership-versions"

# Clone repo if needed
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi

mkdir -p "$OUT_DIR"

cd "$REPO_DIR"

# Make sure main is up to date
git fetch origin main

# List commits that changed the file.
# Format: SHA<TAB>commit-date
git log origin/main \
  --follow \
  --format='%H%x09%cs' \
  -- "$FILE_PATH" |
while IFS=$'\t' read -r sha commit_date; do

  short_sha="${sha:0:7}"

  out_file="../${OUT_DIR}/committee-membership-${commit_date}-${short_sha}.yaml"

  echo "Saving ${out_file}"

  git show "${sha}:${FILE_PATH}" > "$out_file" || {
    echo "Could not extract ${FILE_PATH} at ${sha}"
  }

done


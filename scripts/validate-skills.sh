#!/usr/bin/env bash
# Validates every skills/**/SKILL.md has correct frontmatter:
# - starts with a --- delimited YAML block
# - `name` matches the containing directory name
# - `description` is present and non-empty
set -euo pipefail

status=0

while IFS= read -r -d '' skill_file; do
  dir=$(dirname "$skill_file")
  expected_name=$(basename "$dir")

  if ! head -n 1 "$skill_file" | grep -q '^---$'; then
    echo "::error file=$skill_file::Missing YAML frontmatter (must start with ---)"
    status=1
    continue
  fi

  frontmatter=$(awk '/^---$/{c++; next} c==1' "$skill_file")

  name=$(echo "$frontmatter" | grep -E '^name:' | sed -E 's/^name:[[:space:]]*//')
  description=$(echo "$frontmatter" | grep -E '^description:' | sed -E 's/^description:[[:space:]]*//')

  if [[ -z "$name" ]]; then
    echo "::error file=$skill_file::Missing 'name' field in frontmatter"
    status=1
  elif [[ "$name" != "$expected_name" ]]; then
    echo "::error file=$skill_file::frontmatter name '$name' does not match directory name '$expected_name'"
    status=1
  fi

  if [[ -z "$description" ]]; then
    echo "::error file=$skill_file::Missing 'description' field in frontmatter"
    status=1
  fi
done < <(find skills -name 'SKILL.md' -print0)

if [[ $status -ne 0 ]]; then
  echo "Skill validation failed."
  exit 1
fi

echo "All SKILL.md files valid."

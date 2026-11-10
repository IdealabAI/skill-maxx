#!/bin/bash
# This script supports macOS Bash 3.2 and later.
set -euo pipefail
export LC_ALL=C

fail() { printf 'Skill creation failed: %s\n' "$*" >&2; exit 1; }
assert_no_links() {
    local cursor=$1
    while [ -n "$cursor" ]; do
        [ ! -L "$cursor" ] || fail "The path contains a link: $cursor"
        [ "$cursor" != / ] || break
        cursor=$(dirname "$cursor")
        [ "$cursor" != . ] || break
    done
}

[ "$#" -eq 1 ] || fail 'You must supply one skill name. Usage: /bin/bash scripts/newskill.sh my-new-skill'
name=$1
[[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ "${#name}" -le 64 ] ||
    fail 'The skill name must use 1-64 lowercase letters or digits, with single hyphens between groups.'
case "$name" in
    all|con|prn|aux|nul|com[1-9]|lpt[1-9]) fail "The skill name is reserved: $name" ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P) || fail 'The repository directory could not be resolved.'
source_root="$repo_root/skills"
assert_no_links "$source_root"
[ -d "$source_root" ] || fail "The repository skills directory is missing: $source_root"
destination="$source_root/$name"
assert_no_links "$destination"
[ ! -e "$destination" ] || fail "The skill destination already exists: $destination"

mkdir "$destination" || fail "The skill directory could not be created: $destination"
entry="$destination/SKILL.md"
if ! (set -o noclobber; cat > "$entry" <<EOF
---
name: $name
description: TODO — Describe the skill and the requests that should activate it.
---

# $name

TODO — Replace this paragraph with the skill instructions.
EOF
); then
    fail "The skill file could not be written: $entry"
fi

printf 'The new skill file is at: %s\n' "$entry"
printf '%s\n' \
    'You must replace both TODO placeholders in SKILL.md before installing the skill.' \
    'You can install the skill for both agents in an existing project with the following command.' \
    'You must replace [REPO DIR], [SKILL-NAME], and [PROJECT DIR] with your repository path, skill name, and target project path.' \
    '/bin/bash "[REPO DIR]/scripts/install.sh" --skills "[SKILL-NAME]" --project-path "[PROJECT DIR]"'

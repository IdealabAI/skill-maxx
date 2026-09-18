#!/bin/bash
set -euo pipefail
repository=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/skill-maxx-tests-XXXXXXXX")
test_root=$(cd "$test_root" && pwd -P)
trap 'rm -rf "$test_root"' EXIT
fixture="$test_root/source repo" project="$test_root/project with spaces" test_home="$test_root/test home"
mkdir -p "$fixture" "$project" "$test_home"
cp -R "$repository/scripts" "$repository/skills" "$fixture/"
installer="$fixture/scripts/install.sh"
checks=0
assert() { "$@" || { printf 'Assertion failed: %s\n' "$*" >&2; exit 1; }; checks=$((checks + 1)); }
run() { (cd "$project" && env HOME="$test_home" bash "$installer" "$@"); }
reject() { if run "$@" >"$test_root/rejection.log" 2>&1; then printf 'Unexpected success: %s\n' "$*" >&2; exit 1; fi; checks=$((checks + 1)); }
run --preview
assert test ! -e "$project/.agents"
run
for agent_dir in .agents .claude; do
    for skill in echo progress-reporting; do
        assert diff -qr "$fixture/skills/$skill" "$project/$agent_dir/skills/$skill"
    done
done
assert test "$(run | grep -c '^Unchanged:')" -eq 4
printf '\nLocal edit.\n' >> "$project/.agents/skills/echo/SKILL.md"
reject
assert grep -q 'Local edit' "$project/.agents/skills/echo/SKILL.md"
printf 'Keep me.\n' > "$project/.agents/skills/unrelated.txt"
run --replace --skills echo
assert diff -qr "$fixture/skills/echo" "$project/.agents/skills/echo"
assert grep -q 'Keep me.' "$project/.agents/skills/unrelated.txt"
run --scope global --agent codex --skills echo
assert test -f "$test_home/.agents/skills/echo/SKILL.md"
assert test ! -e "$test_home/.claude"
assert test ! -e "$test_home/.agents/skills/progress-reporting"
run --scope global --agent claude-code --skills echo,progress-reporting
assert test -f "$test_home/.claude/skills/progress-reporting/SKILL.md"
fresh="$test_root/explicit project"
mkdir "$fresh"
reject --project-path "$fresh" --skills echo,missing
assert test ! -e "$fresh/.agents"
run --project-path "$fresh" --agent claude-code --skills echo
assert test -f "$fresh/.claude/skills/echo/SKILL.md"
reject --agent invalid
reject --scope invalid
reject --skills ../echo
reject --skills echo,
reject --scope global --project-path .
reject --project-path does-not-exist
reject --agent
reject --unknown
printf '\nChanged.\n' >> "$fresh/.claude/skills/echo/SKILL.md"
reject --project-path "$fresh" --skills echo
assert test ! -e "$fresh/.agents"
printf 'Invalid metadata.\n' > "$fixture/skills/echo/SKILL.md"
reject --skills echo --replace
cp "$repository/skills/echo/SKILL.md" "$fixture/skills/echo/SKILL.md"
mkdir "$test_root/linked project" "$test_root/outside"
ln -s "$test_root/outside" "$test_root/linked project/.agents"
if [ -L "$test_root/linked project/.agents" ]; then
    reject --project-path "$test_root/linked project" --skills echo --replace
    assert test -z "$(ls -A "$test_root/outside")"
    ln -s "$test_root/outside/missing" "$project/.agents/skills/echo/link"
    reject --skills echo --replace
    rm "$project/.agents/skills/echo/link"
else
    if [ "$(uname -s)" = Darwin ]; then printf 'Native macOS symlink setup failed.\n' >&2; exit 1; fi
    printf 'SKIPPED: This host did not create a real symlink; macOS CI requires these checks.\n'
fi
reject --project-path "$fixture/skills/echo" --skills echo --replace
mkdir -p "$fixture/skills/echo/references/empty"
printf 'Resource.\n' > "$fixture/skills/echo/.resource"
run --skills echo --replace
assert test -f "$project/.agents/skills/echo/.resource"
assert test -d "$project/.agents/skills/echo/references/empty"
assert diff -qr "$fixture/skills/echo" "$project/.agents/skills/echo"
printf 'Passed %s Bash installer checks.\n' "$checks"

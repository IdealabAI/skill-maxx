#!/bin/bash
# Compatible with macOS Bash 3.2.
set -euo pipefail
fail() { printf 'Installation failed: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: bash install.sh [--agent codex|claude-code|both] [--scope project|global]
  [--skills all|name,name] [--project-path PATH] [--preview] [--replace]
The defaults install all skills for both agents into the current project directory.
EOF
}
agent=both scope=project selected=all project_path="$PWD" preview=false replace=false explicit_project=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --agent|--scope|--skills|--project-path)
            [ "$#" -ge 2 ] && [ -n "$2" ] || fail "Missing value for $1"
            case "$1" in
                --agent) agent=$2 ;; --scope) scope=$2 ;; --skills) selected=$2 ;;
                --project-path) project_path=$2; explicit_project=true ;;
            esac
            shift 2 ;;
        --preview) preview=true; shift ;; --replace) replace=true; shift ;;
        --help|-h) usage; exit 0 ;; *) fail "Unknown option: $1" ;;
    esac
done
case "$agent" in codex|claude-code|both) ;; *) fail "Invalid agent: $agent" ;; esac
case "$scope" in project|global) ;; *) fail "Invalid scope: $scope" ;; esac
if [ "$scope" = global ] && $explicit_project; then fail '--project-path cannot be combined with global scope.'; fi

assert_no_links() {
    local cursor=$1
    while [ -n "$cursor" ]; do
        [ ! -L "$cursor" ] || fail "Links are not supported: $cursor"
        [ "$cursor" != / ] || break
        cursor=$(dirname "$cursor")
        [ "$cursor" != . ] || break
    done
}
assert_tree() {
    local invalid
    invalid=$(find "$1" ! -type d ! -type f -print) || fail "Cannot inspect $1"
    [ -z "$invalid" ] || fail "Only ordinary files and directories are supported: $invalid"
}
# pwd -P resolves macOS's system /var and /tmp aliases before destination checks.
source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd -P) || fail 'Missing skills directory.'
base=$project_path
if [ "$scope" = global ]; then base=${HOME:?HOME must be set}; fi
[ -d "$base" ] || fail "The target project or home directory must exist: $base"
assert_no_links "$base"
base=$(cd "$base" && pwd -P)
skills=()
if [ "$selected" = all ]; then
    for source in "$source_root"/*; do
        [ -d "$source" ] || continue
        skills[${#skills[@]}]=$(basename "$source")
    done
else
    case "$selected" in ,*|*,|*,,*) fail 'Empty skill name.' ;; esac
    IFS=',' read -r -a skills <<< "$selected"
fi
[ "${#skills[@]}" -gt 0 ] || fail 'Select at least one skill.'
agents=("$agent")
if [ "$agent" = both ]; then agents=(codex claude-code); fi
sources=() destinations=() statuses=()
for skill in "${skills[@]}"; do
    [[ "$skill" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ "${#skill}" -le 64 ] || fail "Invalid skill name: $skill"
    source="$source_root/$skill"
    assert_no_links "$source"
    [ -f "$source/SKILL.md" ] || fail "Unknown or incomplete skill: $skill"
    assert_tree "$source"
    # This repository's portable metadata contract uses a four-line header.
    metadata=$(head -n 4 "$source/SKILL.md" | tr -d '\r')
    expected=$(printf '%s\nname: %s\n' '---' "$skill")
    [ "$(printf '%s\n' "$metadata" | head -n 2)" = "$expected" ] || fail "Invalid skill metadata: $skill"
    printf '%s\n' "$metadata" | sed -n '3p' | grep -Eq '^description: .+' || fail "Missing description: $skill"
    [ "$(printf '%s\n' "$metadata" | sed -n '4p')" = '---' ] || fail "Invalid frontmatter: $skill"
    for target_agent in "${agents[@]}"; do
        relative_root=.agents/skills
        if [ "$target_agent" = claude-code ]; then relative_root=.claude/skills; fi
        destination="$base/$relative_root/$skill"
        case "$destination/" in "$source_root/"*) fail 'Source and destination skill trees must not overlap.' ;; esac
        case "$source_root/" in "$destination/"*) fail 'Source and destination skill trees must not overlap.' ;; esac
        assert_no_links "$destination"
        cursor=$(dirname "$destination")
        while [ ! -e "$cursor" ]; do cursor=$(dirname "$cursor"); done
        [ -d "$cursor" ] || fail "A destination parent is not a directory: $cursor"
        status=install
        if [ -e "$destination" ]; then
            [ -d "$destination" ] || fail "The destination is not a directory: $destination"
            assert_tree "$destination"
            if diff -qr "$source" "$destination" >/dev/null; then status=unchanged
            elif ! $replace; then fail "Different content exists at $destination. Use --replace to replace this skill."
            fi
        fi
        sources[${#sources[@]}]=$source
        destinations[${#destinations[@]}]=$destination
        statuses[${#statuses[@]}]=$status
    done
done
for ((i=0; i<${#sources[@]}; i++)); do
    destination=${destinations[$i]}
    if [ "${statuses[$i]}" = unchanged ]; then printf 'Unchanged: %s\n' "$destination"; continue; fi
    if $preview; then printf 'Would install: %s\n' "$destination"; continue; fi
    assert_no_links "$destination"
    root=$(dirname "$destination")
    mkdir -p "$root"
    stage=$(mktemp -d "$root/.skill-stage-XXXXXXXX")
    if ! cp -R "${sources[$i]}/." "$stage/"; then rm -rf "$stage"; fail "Cannot stage $destination"; fi
    backup="${stage}-backup"
    if [ -e "$destination" ]; then mv "$destination" "$backup"; fi
    if ! mv "$stage" "$destination"; then
        if [ -d "$backup" ]; then mv "$backup" "$destination"; fi
        rm -rf "$stage"
        fail "Cannot install $destination"
    fi
    if [ -d "$backup" ]; then rm -rf "$backup"; fi
    printf 'Installed: %s\n' "$destination"
done

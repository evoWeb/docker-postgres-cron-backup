#!/usr/bin/env bash
# Generates CHANGELOG.md from the git tags and commit subjects.
# Notes that cannot be derived from commit subjects, like breaking changes,
# are taken from Build/ReleaseNotes/<tag>.md and placed above the changes.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NOTES_DIR=Build/ReleaseNotes
OUTPUT=CHANGELOG.md

function section {
    local title=$1 range=$2 notes="${NOTES_DIR}/${3:-}.md"

    printf '\n## %s\n' "${title}"
    if [ -n "${3:-}" ] && [ -f "${notes}" ]; then
        printf '\n'
        cat "${notes}"
    fi
    printf '\n### Changes\n\n'
    git log --no-merges --format='- %s' "${range}"
}

mapfile -t TAGS < <(git tag --list --sort=-v:refname)

{
    printf '# Changelog\n'

    if [ "${#TAGS[@]}" -eq 0 ]; then
        section "Unreleased" HEAD
    else
        if [ -n "$(git rev-list "${TAGS[0]}..HEAD")" ]; then
            section "Unreleased" "${TAGS[0]}..HEAD"
        fi

        for i in "${!TAGS[@]}"; do
            TAG=${TAGS[$i]}
            DATE=$(git log -1 --format=%cs "${TAG}")
            if [ $((i + 1)) -lt "${#TAGS[@]}" ]; then
                RANGE="${TAGS[$((i + 1))]}..${TAG}"
            else
                RANGE=${TAG}
            fi
            # Tags pointing to the same commit as the previous one have no changes of their own
            if [ -n "$(git rev-list "${RANGE}")" ]; then
                section "${TAG} - ${DATE}" "${RANGE}" "${TAG}"
            fi
        done
    fi
} > "${OUTPUT}"

echo "=> ${OUTPUT} written"

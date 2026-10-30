#!/usr/bin/env bash
# Generates CHANGELOG.md from the git tags and commit subjects.
# Notes that cannot be derived from commit subjects, like breaking changes,
# are taken from Build/ReleaseNotes/<tag>.md and placed above the changes.
#
# Usage: changelog.sh [<release>]
# With a release given, the commits after the latest tag are listed under
# that release instead of "Unreleased", so the changelog can be committed
# before the release gets tagged.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

RELEASE=${1:-}
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
    # The release commits only update this changelog
    git log --no-merges --invert-grep --grep='^\[TASK\] Release [0-9]' --format='- %s' "${range}"
}

mapfile -t TAGS < <(git tag --list --sort=-v:refname)

{
    printf '# Changelog\n'

    HEAD_RANGE=HEAD
    [ "${#TAGS[@]}" -gt 0 ] && HEAD_RANGE="${TAGS[0]}..HEAD"
    if [ -n "$(git rev-list "${HEAD_RANGE}")" ]; then
        if [ -n "${RELEASE}" ]; then
            section "${RELEASE} - $(date +%F)" "${HEAD_RANGE}" "${RELEASE}"
        else
            section "Unreleased" "${HEAD_RANGE}"
        fi
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
} > "${OUTPUT}"

echo "=> ${OUTPUT} written"

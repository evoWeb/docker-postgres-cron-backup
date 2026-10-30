#!/usr/bin/env bash
# Commits the changelog for a release and tags that commit, so the tagged
# state contains its own changelog. Pushing is left to the caller.
#
# Usage: release.sh <x.y.z>

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

RELEASE=${1:-}

function fail {
    echo "=> ERROR: $1" >&2
    exit 1
}

[[ "${RELEASE}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Usage: make release RELEASE=x.y.z"
[ "$(git branch --show-current)" = "main" ] || fail "Releases are only created from main"
[ -z "$(git status --porcelain)" ] || fail "The working tree is not clean, commit release notes first"
! git rev-parse -q --verify "refs/tags/${RELEASE}" > /dev/null || fail "Tag ${RELEASE} already exists"

LATEST=$(git tag --list --sort=-v:refname | head -1)
if [ -n "${LATEST}" ]; then
    [ "$(printf '%s\n%s\n' "${LATEST}" "${RELEASE}" | sort -V | tail -1)" = "${RELEASE}" ] \
        || fail "${RELEASE} is not newer than the latest tag ${LATEST}"
    [ -n "$(git rev-list "${LATEST}..HEAD")" ] || fail "No commits since ${LATEST}"
fi

./Build/changelog.sh "${RELEASE}"
git add CHANGELOG.md
git commit -q -m "[TASK] Release ${RELEASE}" -m "Update CHANGELOG.md for release ${RELEASE}."

# verbatim keeps the markdown headings, which git would strip as comments
{ printf 'Release %s\n\n' "${RELEASE}"; ./Build/release-notes.sh "${RELEASE}"; } \
    | git tag -a --cleanup=verbatim -F - "${RELEASE}"

echo "=> Release ${RELEASE} tagged, publish it with: git push origin main ${RELEASE}"

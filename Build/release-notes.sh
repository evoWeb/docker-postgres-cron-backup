#!/usr/bin/env bash
# Prints the section of a release from CHANGELOG.md, without its heading.
#
# Usage: release-notes.sh <release>

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

RELEASE=${1:?Usage: release-notes.sh <release>}

awk -v release="${RELEASE}" '
    /^## / { if (found) exit; found = ($2 == release); next }
    found && (NF || started) { lines[++count] = $0; started = 1; if (NF) last = count }
    END { for (i = 1; i <= last; i++) print lines[i] }
' CHANGELOG.md

#!/usr/bin/env bash
# Runs the PR validation workflow (.github/workflows/validation.yml) locally with act,
# so the composite action can be exercised without pushing to GitHub.
#
# Usage:
#   ./scripts/test-action-with-act.sh                # run every job in the workflow
#   ./scripts/test-action-with-act.sh -j validate-outputs   # run a single job (any extra act flags are passed through)
set -euo pipefail

if ! command -v act >/dev/null 2>&1; then
  echo "Error: act is not installed. See https://github.com/nektos/act#installation (e.g. 'brew install act')." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker daemon is not reachable. act needs Docker to run job containers and for the action's own 'kind create cluster' step." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

# act persists its tool cache (node/python/kind/etc.) in a named Docker volume across separate
# runs of this script, unlike a real GitHub-hosted runner which always starts from a fresh VM.
# The "Install Solo" step's `npm install -g` isn't idempotent against a pre-existing global
# install, so a `solo` binary left behind by a previous run causes `npm error EEXIST`. Clear any
# leftover solo install from the cached node toolchains before each run to keep them fresh.
echo "Resetting solo install in the shared act tool cache..."
docker run --rm -v act-toolcache:/data alpine sh -c '
  for nodebin in /data/node/*/*/; do
    rm -rf "${nodebin}bin/solo" "${nodebin}lib/node_modules/@hiero-ledger" "${nodebin}lib/node_modules/@hashgraph"
  done
' >/dev/null 2>&1 || true

echo "Running validation.yml jobs with act (this deploys a full Solo test network per job and can take a long time)..."
# Jobs are forced to run one at a time: every job deploys a kind cluster named "solo-e2e" and
# installs solo into the same shared act tool-cache volume, so running jobs concurrently causes
# kind cluster name collisions and racing "npm install -g" processes stomping on each other.
act --concurrent-jobs 1 pull_request "$@"

#!/usr/bin/env bash
# Stage proven Metrics payloads; publication still requires human review and merge.
set -Eeuo pipefail
: "${GITHUB_WORKSPACE:?}"
: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_SHA:?}"
source_root="$GITHUB_WORKSPACE"
checkout="$source_root/repository"
target=repo/openeuler-22.03-lts-sp4/bigtop-3.6/ambari-metrics/3.0.0
python3 "$source_root/scripts/metrics-release/stage.py" --candidate "$source_root/candidate" --target "$checkout/$target"
cd "$checkout"
git switch -c "ci/rpm-repo-ambari-metrics-3.0.0-$GITHUB_RUN_ID"
timeout --kill-after=10 480 docker run --rm -v "$checkout/$target:/target" openeuler/openeuler:22.03-lts-sp4 \
  bash -c 'set -euo pipefail; timeout 300 dnf -y --setopt=timeout=30 --setopt=retries=2 --disablerepo="*" --enablerepo=OS,everything install createrepo_c; createrepo_c --no-database /target'
python3 "$source_root/scripts/metrics-release/stage.py" --verify-metadata --target "$checkout/$target"
git lfs install --local
git add -- "$target"
git diff --cached --check
for rpm_path in "$target"/*.rpm; do
  [[ "$(git check-attr filter -- "$rpm_path")" == *'filter: lfs' ]]
  [[ "$(git cat-file -s ":$rpm_path")" -lt 300 ]]
done
if git diff --cached --quiet; then
  echo 'Identical tested Metrics repository is already present.'
  exit 0
fi
git -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -m 'repo: add tested Ambari Metrics 3.0.0 Collector and Monitor RPMs'
git push origin HEAD
body_file="$(mktemp)"
trap 'rm -f "$body_file"' EXIT
cat > "$body_file" <<EOF
Publishes the two original Collector/Monitor RPMs validated by Metrics candidate run $GITHUB_RUN_ID.
Includes immutable source and packaging identities, original build/test run IDs, exact SHA256 checksums,
repository metadata, actual CPU/memory queries and historical plus fresh metrics after all services restart.
This PR requires human review and merge. No RPM has been recompiled by this promotion workflow.
EOF
gh pr create --repo "$GITHUB_REPOSITORY" --base main \
  --title 'repo: add tested Ambari Metrics 3.0.0 Collector and Monitor' --body-file "$body_file"

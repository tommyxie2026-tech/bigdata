#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
TEST_RUN_ID="${TEST_RUN_ID:?TEST_RUN_ID is required}"
TEST_WORKFLOW_PATH="${TEST_WORKFLOW_PATH:?TEST_WORKFLOW_PATH is required}"
SOURCE_SHA="${SOURCE_SHA:?SOURCE_SHA is required}"
REPO_CHECKOUT="${REPO_CHECKOUT:?REPO_CHECKOUT is required}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

test_run="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${TEST_RUN_ID}")"
jq -e --arg repository "${GITHUB_REPOSITORY}" \
  --arg workflow "${TEST_WORKFLOW_PATH}" \
  '.conclusion == "success" and .head_repository.full_name == $repository and .path == $workflow' \
  <<< "${test_run}" > /dev/null

cd "${REPO_CHECKOUT}"
git lfs install --local
branch="ci/rpm-repo-${COMPONENT}-${VERSION}-${GITHUB_RUN_ID}"
git switch -c "${branch}"
mkdir -p repo
cp "${GITHUB_WORKSPACE}/repo/.gitattributes" repo/.gitattributes
cp "${GITHUB_WORKSPACE}/repo/README.md" repo/README.md
bash "${GITHUB_WORKSPACE}/scripts/ci/stage-tested-rpms.sh"
git add repo
git diff --cached --check
while IFS= read -r -d '' rpm; do
  relative="${rpm#./}"
  [[ "$(git check-attr filter -- "${relative}")" == *'filter: lfs' ]]
  [[ "$(git cat-file -s ":${relative}")" -lt 300 ]]
done < <(find "repo/openeuler-22.03-lts-sp4/bigtop-3.6/${COMPONENT}/${VERSION}" \
  -maxdepth 1 -type f -name '*.rpm' -print0)

if git diff --cached --quiet; then
  echo "RPM repository already contains ${COMPONENT} ${VERSION}." >> "${GITHUB_STEP_SUMMARY}"
  exit 0
fi

git -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m "repo: add tested ${COMPONENT} ${VERSION} RPMs"
git push origin "${branch}"
body_file="$(mktemp)"
cat > "${body_file}" <<EOF
Adds the ${COMPONENT} ${VERSION} RPMs from successful ${TEST_WORKFLOW_PATH} run ${TEST_RUN_ID}.
Promotion workflow commit: ${SOURCE_SHA}
Release candidate: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
EOF
pr_url="$(gh pr create --repo "${GITHUB_REPOSITORY}" \
  --base main --head "${branch}" \
  --title "repo: add tested ${COMPONENT} ${VERSION} RPMs" \
  --body-file "${body_file}")"
echo "RPM repository PR: ${pr_url}" >> "${GITHUB_STEP_SUMMARY}"
gh pr merge "${pr_url}" --repo "${GITHUB_REPOSITORY}" --squash
echo "Merged tested RPMs into main/repo." >> "${GITHUB_STEP_SUMMARY}"

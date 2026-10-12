#!/usr/bin/env bash
set -euo pipefail

CHECK_RESULT="${CHECK_RESULT:?CHECK_RESULT is required}"
INSTALL_RESULT="${INSTALL_RESULT:?INSTALL_RESULT is required}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

case "${CHECK_RESULT}" in
  0)
    if [[ "${INSTALL_RESULT}" == 0 ]]; then
      echo 'already_current=true' >> "${GITHUB_OUTPUT}"
      echo "Exact repository and clean DNF install verified; fast path accepted."
    else
      echo 'already_current=false' >> "${GITHUB_OUTPUT}"
      echo "Clean DNF install did not pass; normal Build/Test/Release required." >&2
    fi
    ;;
  1)
    echo 'already_current=false' >> "${GITHUB_OUTPUT}"
    echo "Repository content, version, or source identity mismatch; normal lifecycle required."
    ;;
  *)
    echo "Repository checker failed safely with exit ${CHECK_RESULT}." >&2
    exit "${CHECK_RESULT}"
    ;;
esac

#!/usr/bin/env bash
# Compare two directories for differences.
# Source credits: https://github.com/scaleoutllc/reference-architecture/blob/main/bin/diff-dir
set -euo pipefail
SCRIPT_PATH="$(cd "$(dirname "$BASH_SOURCE[0]")"; pwd -P)"

function usage {
  echo "Usage: $0 <path-a> <path-b>"
  exit 1
}

if test "$#" -ne 2; then
    usage
fi

A_PATH="$1"
if [[ ! -d "${A_PATH}" ]]; then
  echo "No directory found in ${A_PATH}."
  exit 1
fi

B_PATH="$2"
if [[ ! -d "${B_PATH}" ]]; then
  echo "No directory found in ${B_PATH}."
  exit 1
fi

# Original Scaleout implementation, GNU Find
# A="$(find $A_PATH -type d -name '.*' -prune -o -type f ! -name '.*' -printf "%P\n" | sort)"
# B="$(find $B_PATH -type d -name '.*' -prune -o -type f ! -name '.*' -printf "%P\n" | sort)"

# macOS compatible implementation, BSD Find
A="$(find $A_PATH -type d -name '.*' -prune -o -type f ! -name '.*' -print | sed "s|^$A_PATH/||" | sort)"
B="$(find $B_PATH -type d -name '.*' -prune -o -type f ! -name '.*' -print | sed "s|^$B_PATH/||" | sort)"

echo "Files unique to $1:"
comm -23 <(echo "$A") <(echo "$B")

echo "Files unique to $2:"
comm -23 <(echo "$B") <(echo "$A")

echo "File comparison:"
for file in $(comm -12 <(echo "$A") <(echo "$B")); do
  diff "$A_PATH/$file" "$B_PATH/$file" || echo $file
done
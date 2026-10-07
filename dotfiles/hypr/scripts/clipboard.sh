#!/usr/bin/env bash
# clipboard.sh — pick an old clipboard entry (cliphist) and copy it back.
set -euo pipefail

cliphist list | fuzzel --dmenu --with-nth 2 | cliphist decode | wl-copy

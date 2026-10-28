#!/usr/bin/env bash
# extract.sh BODY OUT: each ```nix block of an issue body becomes OUT/block-N.nix (CRLF from GitHub stripped)
set -eu
mkdir -p "$2"
tr -d '\r' < "$1" | awk -v out="$2" '
  /^[ \t]*```[ \t]*nix[ \t]*$/ { n++; f = sprintf("%s/block-%d.nix", out, n); on = 1; next }
  /^[ \t]*```[ \t]*$/ && on { on = 0; close(f); next }
  on { print > f }'
ls "$2" | grep -c . || true

#!/bin/zsh
# Render the app version stored in .version, lux-fw style:
# v123 -> v1.2.3, v1123 -> v11.2.3, v5 -> v0.0.5. A dotted tag or `dev`
# is printed unchanged. `.version` is written by `hammer version`.
#
#   tools/version.sh          print v1.2.3
#   tools/version.sh --short  print 1.2.3
#   tools/version.sh --count  print the raw commit count (11)

set -eu
cd "${0:A:h}/.."

if [[ -f .version ]]; then
  raw=$(< .version)
else
  raw=dev
fi

if [[ "$raw" =~ '^v[0-9]+$' ]]; then
  count=${raw#v}
  padded=$(printf '%03d' "$count")
  dotted="v${padded[1,-3]}.${padded[-2]}.${padded[-1]}"
else
  count='0'
  dotted=$raw
fi

case "${1:-}" in
  --count) print "$count" ;;
  --short) print "${dotted#v}" ;;
  *)       print "$dotted" ;;
esac

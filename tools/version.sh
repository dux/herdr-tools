#!/bin/zsh
# Print the app version from .version (YAML `version: X.Y.Z`, written by
# `hammer deploy` via vstamp count --release). Missing or unstamped prints dev.
#
#   tools/version.sh          print v1.2.3
#   tools/version.sh --short  print 1.2.3
#   tools/version.sh --count  print the commit count behind it (123)

set -eu
cd "${0:A:h}/.."

version=''
if [[ -f .version ]]; then
  version=$(sed -n 's/^version: *\([^ #]*\).*/\1/p' .version)
fi

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  [[ "${1:-}" == --count ]] && print 0 || print dev
  exit 0
fi

parts=("${(@s:.:)version}")
case "${1:-}" in
  --count) print $(( parts[1] * 100 + parts[2] * 10 + parts[3] )) ;;
  --short) print "$version" ;;
  *)       print "v$version" ;;
esac

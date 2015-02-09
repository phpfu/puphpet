#!/bin/sh
#
# Usage: git semver-tags [-p|--pre]
#
# Lists semver tags in the repository in order from newest to oldest.
#
# Useful for e.g. programmatically finding the latest release tag:
# `git semver-tags | head -n 1`.
#
# Tag names must be valid according to the SemVer 1.0.0 specification
# (http://semver.org/spec/v1.0.0.html), with the following additional
# considerations:
#
#  1. The tag name may optionally start with a "v".
#  2. The minor and patch versions may be omitted in the tag name, in
#     which case they will be treated as equivalent to "0".
#
# By default, tags with prerelease segments are not included in the
# list. To see all tags, including those with prerelease segments,
# pass the `-p` or `--pre` option.
#
# Copyright (c) 2012 Sam Stephenson <sstephenson@gmail.com>
# Released into the public domain 2012-12-21
# Ref: https://gist.github.com/sstephenson/4354805

set -e

preprocess_tags() {
  sed -e "
    # If the line isn't a semver tag name, delete it and
    # continue processing.
    /^v\{0,1\}[0-9]\{1,\}\(\.[0-9]\{1,\}\)\{0,1\}\(\.[0-9]\{1,\}\)\{0,1\}\(-[A-Za-z0-9-]\{1,\}\)\{0,1\}$/ !{
      d
      b
    }

    # Store the semver tag in the hold buffer.
    h

    # Strip off the leading 'v', if present, and replace all
    # dots with spaces.
    s/^v//
    s/\./ /g

    # If there is no prerelease segment, add one called '~'
    # so it occurs last when sorted.
    /-./ !{
      s/-\{0,1\}$/-~/
    }

    # Two spaces in the string means that major, minor, and
    # patch versions are specified. Skip to :end.
    / .* / {
      b end
    }

    # One space in the string means there's no patch version.
    # Set it to '0' and skip to :end.
    / / {
      s/-.*$/ 0&/
      b end
    }

    # No spaces in the string means there's only a major
    # version. Set minor and patch to '0'.
    s/-.*$/ 0 0&/

  :end

    # Replace the prerelease segment junction with a space.
    s/-/ /

    # Restore the semver tag name from the hold buffer.
    G

    # Remove the newline added by the hold buffer restoration
    # so the semver tag name appears on the same line.
    s/\n/ /
  "
}

format_preprocessed_tags_for_sorting() {
  awk '
    # Record each line, keeping track of the maximum widths of
    # the first three columns.
    {
      lines[NR] = $0
      for (i = 1; i <= 3; i++) {
        max[i] < length($i) && max[i] = length($i)
      }
    }

    # Loop over each line and print it in a format suitable for
    # ASCII sorting. First, print each of the first three columns
    # zero-padded to its maximum width, followed immediately by
    # the fourth column, then a space, and finally the fifth.
    END {
      for (i = 1; i <= NR; i++) {
        split(lines[i], parts, FS)
        printf("%0" max[1] "d%0" max[2] "d%0" max[3] "d%s %s\n",
          parts[1], parts[2], parts[3], parts[4], parts[5])
      }
    }
  '
}

filter_prerelease_tags() {
  if [ -n "$prerelease" ]; then
    cat
  else
    grep "~"
  fi
}

usage() {
  echo "usage: git semver-tags [-p|--pre]" >&2
  exit 1
}

unset prerelease

for arg; do
  case "$arg" in
  -p | --pre )
    prerelease="1"
    ;;
  * )
    usage
    ;;
  esac
done

git tag -l |
  preprocess_tags |
  filter_prerelease_tags |
  format_preprocessed_tags_for_sorting |
  sort -r |
  awk '{print $2}'
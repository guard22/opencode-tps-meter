#!/usr/bin/env bash

MIN_TESTED="1.3.13"
LATEST_TESTED="1.14.20"
TESTED_VERSIONS=("1.3.13" "1.3.14" "1.3.15" "1.3.16" "1.3.17" "1.4.0" "1.4.1" "1.14.20")

is_semver_version() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

resolve_upstream_tag() {
  if [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s\n' "$1"
    return 0
  fi
  is_semver_version "$1" || return 1
  printf 'v%s\n' "$1"
}

is_tested_version() {
  local version="$1"
  local tested
  for tested in "${TESTED_VERSIONS[@]}"; do
    if [ "$tested" = "$version" ]; then
      return 0
    fi
  done
  return 1
}

print_tested_versions() {
  printf '%s\n' "${TESTED_VERSIONS[@]}"
}

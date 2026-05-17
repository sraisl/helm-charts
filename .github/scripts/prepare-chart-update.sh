#!/usr/bin/env bash
set -euo pipefail

chart="${CHART:-}"
app_version="${APP_VERSION:-}"
requested_chart_version="$(echo "${CHART_VERSION:-}" | xargs)"

if [[ -z "$chart" || ! "$chart" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid chart name: $chart" >&2
  exit 1
fi

if [[ -z "$app_version" || "$app_version" == *$'\n'* || "$app_version" == *$'\r'* ]]; then
  echo "app_version must be a non-empty single-line value" >&2
  exit 1
fi

if [[ ! "$app_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "app_version must be v-prefixed SemVer, for example v1.0.0: $app_version" >&2
  exit 1
fi

chart_yaml="charts/${chart}/Chart.yaml"
if [[ ! -f "$chart_yaml" ]]; then
  echo "Chart not found: $chart_yaml" >&2
  exit 1
fi

name="$(yq -r '.name // ""' "$chart_yaml")"
current_version="$(yq -r '.version // ""' "$chart_yaml")"
current_app_version="$(yq -r '.appVersion // ""' "$chart_yaml")"

if [[ "$name" != "$chart" ]]; then
  echo "$chart_yaml name does not match input chart '$chart'" >&2
  exit 1
fi

if [[ -z "$current_version" || -z "$current_app_version" ]]; then
  echo "$chart_yaml must contain version and appVersion" >&2
  exit 1
fi

if [[ ! "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Current chart version is not SemVer-compatible: $current_version" >&2
  exit 1
fi

if [[ -n "$requested_chart_version" ]]; then
  if [[ ! "$requested_chart_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
    echo "Requested chart_version is not SemVer-compatible: $requested_chart_version" >&2
    exit 1
  fi
  next_version="$requested_chart_version"
elif [[ "$current_app_version" == "$app_version" ]]; then
  {
    echo "changed=false"
  } >> "$GITHUB_OUTPUT"
  echo "$chart already has appVersion $app_version; nothing to update."
  exit 0
else
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  next_version="${major}.${minor}.$((patch + 1))"
fi

if [[ "$current_version" == "$next_version" && "$current_app_version" == "$app_version" ]]; then
  {
    echo "changed=false"
  } >> "$GITHUB_OUTPUT"
  echo "$chart already has version $next_version and appVersion $app_version; nothing to update."
  exit 0
fi

yq -i ".version = \"${next_version}\" | .appVersion = \"${app_version}\"" "$chart_yaml"

safe_version="$(echo "$app_version" | sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+//; s/-+$//' | cut -c1-80)"
branch="update/${chart}-${safe_version}"
title="Update ${chart} to ${app_version}"
body="Updates \`${chart}\` to app version \`${app_version}\` and bumps the Helm chart version to \`${next_version}\`."

{
  echo "changed=true"
  echo "branch=$branch"
  echo "title=$title"
  echo "body=$body"
} >> "$GITHUB_OUTPUT"

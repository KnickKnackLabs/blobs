#!/usr/bin/env bash

s3_check_tools() {
  if ! command -v "${MC:-mc}" >/dev/null; then
    echo "ERROR: mc (MinIO client) not found. Run: mise install" >&2
    return 1
  fi
}

s3_alias_exists() {
  local aliases
  aliases=$("${MC:-mc}" alias list "$B2_ALIAS") || return 1
  [[ -n "$aliases" ]]
}

s3_check_config() {
  : "${B2_ALIAS:?B2_ALIAS is not set}"
  : "${B2_BUCKET:?B2_BUCKET is not set}"
  s3_check_tools

  if ! s3_alias_exists; then
    echo "ERROR: mc alias '$B2_ALIAS' not configured. Run: blobs setup" >&2
    return 1
  fi
}

blob_get() {
  local key="$1" dest="$2"
  s3_check_config

  if [[ -z "$dest" ]]; then
    "${MC:-mc}" cat "$B2_ALIAS/$B2_BUCKET/$key"
  else
    "${MC:-mc}" cp -q "$B2_ALIAS/$B2_BUCKET/$key" "$dest"
  fi
}

blob_put() {
  local key="$1" file="$2"
  s3_check_config

  if [[ "$file" == "-" ]]; then
    "${MC:-mc}" pipe -q "$B2_ALIAS/$B2_BUCKET/$key"
  else
    "${MC:-mc}" cp -q "$file" "$B2_ALIAS/$B2_BUCKET/$key"
  fi
}

blob_list() {
  local prefix="$1" json="$2" recursive="$3"
  local target
  local args=(ls)
  s3_check_config
  target="$B2_ALIAS/$B2_BUCKET"

  [[ -z "$prefix" ]] || target="$target/$prefix"
  if [[ "$json" == "true" ]]; then
    args+=(--json)
  fi
  if [[ "$recursive" == "true" ]]; then
    args+=(--recursive)
  fi

  "${MC:-mc}" "${args[@]}" "$target"
}

blob_delete() {
  s3_check_config
  "${MC:-mc}" rm "$B2_ALIAS/$B2_BUCKET/$1"
}

blob_setup() {
  local name endpoint
  local missing=()
  s3_check_tools

  for name in B2_ALIAS B2_ENDPOINT B2_KEY_ID B2_APPLICATION_KEY; do
    [[ -n "${!name:-}" ]] || missing+=("$name")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required env var(s): ${missing[*]}" >&2
    return 1
  fi

  if s3_alias_exists; then
    echo "mc alias '$B2_ALIAS' is already configured."
    return 0
  fi

  endpoint="$B2_ENDPOINT"
  [[ "$endpoint" =~ ^https?:// ]] || endpoint="https://$endpoint"

  "${MC:-mc}" alias set "$B2_ALIAS" "$endpoint" "$B2_KEY_ID" "$B2_APPLICATION_KEY" --api s3v4
  echo "Blob storage configured."
  echo "  Alias:    $B2_ALIAS"
  echo "  Endpoint: $endpoint"
}

blob_welcome() {
  s3_check_config
  printf 'Backend: s3\nAlias:   %s\nBucket:  %s\n' "$B2_ALIAS" "$B2_BUCKET"
}

#!/usr/bin/env bash

remote() {
  local key="$1"

  printf '%s' \
    "${B2_ALIAS}/${B2_BUCKET}/${key}"
}

s3_check_tools() {
  if ! command -v "${MC:-mc}" >/dev/null; then
    echo "ERROR: mc (MinIO client) not found. Run: mise install" >&2
    return 1
  fi
}

s3_alias_exists() {
  local aliases
  aliases=$("${MC:-mc}" alias list "${B2_ALIAS}") || return 1
  [[ -n "${aliases}" ]]
}

blob_check_config() {
  : "${B2_ALIAS:?B2_ALIAS is not set}"
  : "${B2_BUCKET:?B2_BUCKET is not set}"
  s3_check_tools

  if ! s3_alias_exists; then
    echo "ERROR: mc alias '${B2_ALIAS}' not configured. Run: blobs setup" >&2
    return 1
  fi
}

blob_stat() {
  local key="$1"

  "${MC:-mc}" stat --json "$(remote "${key}")" \
  | jq '{ etag, versionID }'
}

blob_source() {
  local alias_info access_key key_hash

  alias_info=$(
    "${MC:-mc}" alias list "${B2_ALIAS}" --json \
    | jq -ce '{ url: .URL, access_key: .accessKey }'
  ) || return

  access_key=$(
    printf '%s\n' "${alias_info}" | jq -er '.access_key'
  ) || return

  if ! key_hash=$(printf '%s' "${access_key}" | shasum -a 256); then
    return 1
  fi

  printf '%s\n' "${alias_info}" \
  | jq -c \
    --arg bucket "${B2_BUCKET}" \
    --arg key_hash "${key_hash%% *}" \
    '{
      backend: "s3",
      url: (.url | rtrimstr("/")),
      bucket: $bucket,
      access_key_hash: $key_hash
    }'
}

blob_get() {
  local key="$1" dest="$2"

  if [[ -z "${dest}" ]]; then
    "${MC:-mc}" cat "$(remote "${key}")"
    return
  fi

  "${MC:-mc}" cp -q "$(remote "${key}")" "${dest}"
}

blob_put() {
  local key="$1" file="$2"

  if [[ "${file}" == "-" ]]; then
    "${MC:-mc}" pipe -q "$(remote "${key}")"
    return
  fi

  "${MC:-mc}" cp -q "${file}" "$(remote "${key}")"
}

blob_list() {
  local prefix="$1" json="$2" recursive="$3"

  local target="${B2_ALIAS}/${B2_BUCKET}"
  [[ -z "${prefix}" ]] || target="${target}/${prefix}"

  local args=(ls)
  if [[ "${json}" == "true" ]]; then args+=(--json); fi
  if [[ "${recursive}" == "true" ]]; then args+=(--recursive); fi

  "${MC:-mc}" "${args[@]}" "${target}"
}

blob_delete() {
  local key="$1"

  "${MC:-mc}" rm "$(remote "${key}")"
}

blob_setup() {
  local name
  local missing=()
  s3_check_tools

  for name in B2_ALIAS B2_ENDPOINT B2_KEY_ID B2_APPLICATION_KEY; do
    [[ -n "${!name:-}" ]] || missing+=("${name}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required env var(s): ${missing[*]}" >&2
    return 1
  fi

  if s3_alias_exists; then
    echo "mc alias '${B2_ALIAS}' is already configured."
    return 0
  fi

  local endpoint="${B2_ENDPOINT}"
  [[ "${endpoint}" =~ ^https?:// ]] || endpoint="https://${endpoint}"

  "${MC:-mc}" alias set \
    "${B2_ALIAS}" \
        "${endpoint}" "${B2_KEY_ID}" "${B2_APPLICATION_KEY}" --api s3v4

  echo "Blob storage configured."
  echo "  Alias:    ${B2_ALIAS}"
  echo "  Endpoint: ${endpoint}"
}

blob_welcome() {
  printf 'Backend: s3\nAlias:   %s\nBucket:  %s\n' \
    "${B2_ALIAS}" \
    "${B2_BUCKET}"
}

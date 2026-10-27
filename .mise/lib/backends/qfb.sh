#!/usr/bin/env bash

blob_check_config() {
  : "${QFB_URL:?QFB_URL is not set}"
  : "${QFB_SOURCE:?QFB_SOURCE is not set}"
  : "${QFB_TOKEN:?QFB_TOKEN is not set}"

  case "$QFB_URL" in
    http://*|https://*) ;;
    *)
      echo "ERROR: QFB_URL must start with http:// or https://" >&2
      return 1
      ;;
  esac

  if ! command -v "${CURL:-curl}" >/dev/null; then
    echo "ERROR: curl not found. Run: mise install" >&2
    return 1
  fi
}

qfb_request() {
  local method="$1" endpoint="$2"
  shift 2

  if [[ "${method}" == "HEAD" ]]; then
    set -- --head "$@"
  fi

  "${CURL:-curl}" --silent --show-error --fail \
    --request "$method" \
    --header "Authorization: Bearer $QFB_TOKEN" \
    --url "${QFB_URL%/}/api/$endpoint" \
    --url-query "source=$QFB_SOURCE" \
    "$@"
}

blob_stat() {
  local key="${1}"
  local etag

  etag=$(
    qfb_request HEAD resources/download \
      --url-query "file=/${key#/}" \
      --output /dev/null \
      --write-out '%header{etag}'
  ) || return

  if [[ -z "${etag}" ]]; then
    printf 'ERROR: QFB returned no ETag.\n' >&2
    return 1
  fi

  # apply a bunch of validation nonsense
  jq -cn \
    --arg etag "${etag}" '{ etag: $etag }'
}

blob_source() {
  local token_hash

  if ! token_hash=$(printf '%s' "${QFB_TOKEN}" | shasum -a 256); then
    return 1
  fi

  jq -cn \
    --arg url "${QFB_URL%/}" \
    --arg source "${QFB_SOURCE}" \
    --arg token_hash "${token_hash%% *}" \
    '{
      backend: "qfb",
      url: $url,
      source: $source,
      token_hash: $token_hash
    }'
}

blob_get() {
  local key="$1" dest="${2:--}"
  qfb_request GET resources/download \
    --url-query "file=/${key#/}" \
    --output "$dest"
}

blob_put() {
  local key="$1" file="$2"

  qfb_request POST resources \
    --url-query "path=/${key#/}" \
    --url-query "override=true" \
    --header "Content-Type: application/octet-stream" \
    --data-binary "@$file" \
    --output /dev/null
}

qfb_list_directory() {
  local directory="$1" recursive="$2"
  local items file_entries folder_entries folder key
  items=$(qfb_request \
    GET resources/items --url-query "path=/$directory" \
  )

  file_entries=$(printf '%s' "$items" | jq -c --arg prefix "$directory" '
    (.files // [])[] |
    {key: (if $prefix == "" then . else $prefix + "/" + . end), type: "file"}
  ')
  if [[ -n "$file_entries" ]]; then
    printf '%s\n' "$file_entries"
  fi

  folder_entries=$(printf '%s' "$items" | jq -c --arg prefix "$directory" '
    (.folders // [])[] |
    {key: (if $prefix == "" then . else $prefix + "/" + . end), type: "folder"}
  ')
  while IFS= read -r folder; do
    [[ -n "$folder" ]] || continue

    if [[ "$recursive" == "true" ]]; then
      key=$(printf '%s' "$folder" | jq -r '.key')
      qfb_list_directory "$key" "$recursive"
    else
      printf '%s\n' "$folder"
    fi
  done <<< "$folder_entries"
}

blob_list() {
  local prefix="${1#/}" json="$2" recursive="$3"
  prefix="${prefix%/}"

  qfb_list_directory "$prefix" "$recursive" |
    if [[ "$json" == "true" ]]; then
      cat
    else
      jq -r '.key + (if .type == "folder" then "/" else "" end)'
    fi
}

blob_delete() {
  local key="$1" info type

  info=$(qfb_request \
    GET resources \
      --url-query "path=/${key#/}" \
  )

  type=$(printf '%s' "$info" | jq -er '.type | strings')
  if [[ "$type" == "directory" ]]; then
    echo "ERROR: Refusing to delete a directory: $key" >&2
    return 1
  fi

  qfb_request \
    DELETE resources --url-query "path=/${key#/}" \
    --output /dev/null
}

blob_setup() {
  blob_check_config

  echo "QFB configuration is set. No local setup is needed."
}

blob_welcome() {
  printf 'Backend: qfb\nURL:     %s\nSource:  %s\n' \
    "$QFB_URL" \
    "$QFB_SOURCE"
}

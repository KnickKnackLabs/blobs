#!/usr/bin/env bash

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
BLOBS_TRACKING_FILE="${STATE_DIR}/blobs/tracking.json"

tracking_read() {
  if [[ ! -e "${BLOBS_TRACKING_FILE}" ]]; then
    printf '[]\n'
    return
  fi

  jq -e 'arrays' "${BLOBS_TRACKING_FILE}"
}

tracking_write() {
  local directory
  directory=$(dirname "${BLOBS_TRACKING_FILE}")

  mkdir -p "${directory}"
  chmod 700 "${directory}"

  local temporary
  temporary=$(mktemp "${BLOBS_TRACKING_FILE}.XXXXXX")

  if ! jq -e 'arrays' > "${temporary}"; then
    rm -f "${temporary}"
    printf 'Invalid tracking data; existing records kept.\n' >&2
    return 1
  fi

  mv "${temporary}" "${BLOBS_TRACKING_FILE}"
}

tracking_find() {
  local source="${1}" key="${2}" file="${3}"
  local records find

  records=$(tracking_read) || return

  find=$(
    printf '%s\n' "${records}" |
      jq -c \
        --argjson source "${source}" \
        --arg key "${key}" \
        --arg file "${file}" \
        '
        .[] | select (
          .source == $source and
          .key == $key and
          .file == $file
        )
        '
  ) || return

  printf '%s\n' "${find}"
}

tracking_save() {
  local source="${1}" key="${2}" file="${3}" etag="${4}"
  local records updated

  records=$(tracking_read) || return

  updated=$(
    printf '%s\n' "${records}" |
      jq \
        --argjson source "${source}" \
        --arg key "${key}" \
        --arg file "${file}" \
        --arg etag "${etag}" \
        '
        # discard previous value
        map(select(
          .source != $source or
          .key != $key or
          .file != $file
        ))

        # insert new value
        + [{
          source: $source,
          key: $key,
          file: $file,
          etag: $etag
        }]
        '
  ) || return

  printf '%s\n' "${updated}" | tracking_write
}

tracking_check() {
  local source="${1}" key="${2}" file="${3}" etag="${4}"
  local record

  if ! record=$(tracking_find "${source}" "${key}" "${file}"); then
    printf 'ERROR: Could not look up records for %s.\n' "${key}" >&2
    return 1
  fi

  if [[ -z "${record}" ]]; then
    printf 'ERROR: No record of %s. Use --force to overwrite.\n' "${key}" >&2
    return 1
  fi

  if ! printf '%s\n' "${record}" | jq -e --arg etag "${etag}" '.etag == $etag' >/dev/null; then
    printf 'ERROR: Remote %s has changed. Use --force to overwrite.\n' "${key}" >&2
    return 1
  fi
}

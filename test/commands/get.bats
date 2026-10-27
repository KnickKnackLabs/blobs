#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "get: streams file contents to stdout without a status message" {
  run blobs get 'sessions/note & plan.md'

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "sample document" ]]
}

@test "get: writes exact bytes to a destination with spaces" {
  destination="${BATS_TEST_TMPDIR}/downloaded note.md"
  printf 'example\000binary\n' > "${storage_dir}/responses/download"

  run blobs get sessions/note.md "${destination}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Downloaded: sessions/note.md"* ]]
  cmp "${storage_dir}/responses/download" "${destination}"
}

@test "get: saves the remote baseline for a downloaded file" {
  destination="${BATS_TEST_TMPDIR}/downloaded note.md"
  tracking_file="${XDG_STATE_HOME}/blobs/tracking.json"

  run blobs get sessions/note.md "${destination}"

  [[ "${status}" -eq 0 ]]
  [[ -f "${tracking_file}" ]]

  etag="fictional-etag"
  if [[ "${BLOB_BACKEND}" == "qfb" ]]; then
    etag='"fictional-etag"'
  fi

  jq -e \
    'length == 1' "${tracking_file}"

  jq -e \
    --arg file "$(realpath "${destination}")" \
    --arg backend "${BLOB_BACKEND}" \
    --arg etag "${etag}" \
    '
    .[0] |
      .source.backend == $backend and
      .key == "sessions/note.md" and
      .file == $file and
      .etag == $etag
    ' "${tracking_file}"
}

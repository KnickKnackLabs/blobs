#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "put: uploads a file's exact bytes and reports success" {
  source="${BATS_TEST_TMPDIR}/source document.pdf"
  printf 'example\000binary\n' > "${source}"

  run blobs put sessions/document.pdf "${source}"

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Uploaded: sessions/document.pdf"* ]]
  cmp "${source}" "${storage_dir}/upload"
}

@test "put: reads stdin when the filename is omitted" {
  run bash -c 'printf "from stdin" | blobs put sessions/note.md'

  [[ "${status}" -eq 0 ]]
  [ "$(cat "${storage_dir}/upload")" = "from stdin" ]
}

@test "put: reads stdin when the filename is dash" {
  run bash -c 'printf "from stdin" | blobs put sessions/note.md -'

  [[ "${status}" -eq 0 ]]
  [ "$(cat "${storage_dir}/upload")" = "from stdin" ]
}

@test "put: rejects a missing local file" {
  run blobs put sessions/note.md "${BATS_TEST_TMPDIR}/missing.md"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"File not found"* ]]
  [ ! -e "${storage_dir}/upload" ]
  [ ! -e "${storage_dir}/requests.log" ]
  [ ! -e "${storage_dir}/requests.jsonl" ]
}

@test "put: a failed upload returns nonzero without reporting success" {
  touch "${storage_dir}/request-fails"

  run blobs put sessions/note.md "${storage_dir}/responses/download"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"simulated request failure"* ]]
  [[ "${output}" != *"Uploaded:"* ]]
}

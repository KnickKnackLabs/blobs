#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_qfb_env
}

@test "qfb: get uses bearer auth and separate source and file query arguments" {
  run blobs get 'sessions/note & plan.md'

  [[ "${status}" -eq 0 ]]

  request=$(last_curl_call)
  [[ "${request}" == *'"GET"'* ]]
  [[ "${request}" == *'"https://files.example.test/api/resources/download"'* ]]
  [[ "${request}" == *'"source=Shared files"'* ]]
  [[ "${request}" == *'"file=/sessions/note & plan.md"'* ]]
  [[ "${request}" == *'"Authorization: Bearer fictional-test-token"'* ]]
}

@test "qfb: put posts a binary body and allows replacement" {
  source="${BATS_TEST_TMPDIR}/source document.pdf"
  printf 'example\000binary\n' > "${source}"

  # shellcheck disable=SC2030,SC2031
  export BLOBS_TEST_EXISTS="false"

  run blobs put sessions/document.pdf "${source}"

  [[ "${status}" -eq 0 ]]

  request=$(last_curl_call)
  [[ "${request}" == *'"POST"'* ]]
  [[ "${request}" == *'"https://files.example.test/api/resources"'* ]]
  [[ "${request}" == *'"override=true"'* ]]
  [[ "${request}" == *'"path=/sessions/document.pdf"'* ]]
  [[ "${request}" == *'"Content-Type: application/octet-stream"'* ]]
  [[ "${request}" == *"\"@${source}\""* ]]
}

@test "qfb: list emits root-relative file and folder records" {
  run blobs list --json

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == $'{"key":"index.md","type":"file"}\n{"key":"sessions","type":"folder"}' ]]
  [[ "$(last_curl_call)" == *'"path=/"'* ]]
}

@test "qfb: list accepts leading and trailing directory slashes" {
  run blobs list --json /sessions/

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == '{"key":"sessions/note & plan.md","type":"file"}' ]]
  [[ "$(last_curl_call)" == *'"path=/sessions"'* ]]
}

@test "qfb: recursive list requests child directories and emits files only" {
  run blobs list --recursive --json

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == $'{"key":"index.md","type":"file"}\n{"key":"sessions/note & plan.md","type":"file"}' ]]
  [[ "$(wc -l < "${QFB_TEST_DIR}/requests.jsonl" | tr -d ' ')" -eq 2 ]]
  [[ "$(last_curl_call)" == *'"path=/sessions"'* ]]
}

@test "qfb: an empty directory produces no records" {
  cp "$BLOBS_TEST_ROOT/fixtures/qfb/empty-directory.json" "${QFB_TEST_DIR}/responses/items.json"

  run blobs list --json

  [[ "${status}" -eq 0 ]]
  [[ -z "${output}" ]]
}

@test "qfb: recursive list reports malformed child responses" {
  printf 'invalid JSON' > "${QFB_TEST_DIR}/responses/sessions/items.json"

  run blobs list --recursive

  [[ "${status}" -ne 0 ]]
}

@test "qfb: delete targets the selected source and path" {
  run blobs delete 'sessions/old note.md'

  [[ "${status}" -eq 0 ]]
  request=$(last_curl_call)
  [[ "${request}" == *'"DELETE"'* ]]
  [[ "${request}" == *'"source=Shared files"'* ]]
  [[ "${request}" == *'"path=/sessions/old note.md"'* ]]
}

@test "qfb: delete refuses directories before sending DELETE" {
  cp "$BLOBS_TEST_ROOT/fixtures/qfb/directory.json" "${QFB_TEST_DIR}/responses/info.json"

  run blobs delete sessions

  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"Refusing to delete a directory"* ]]
  [[ "$(wc -l < "${QFB_TEST_DIR}/requests.jsonl" | tr -d ' ')" -eq 1 ]]
  [[ "$(last_curl_call)" == *'"GET"'* ]]
}

@test "qfb: configuration is required before contacting storage" {
  unset QFB_TOKEN

  run blobs get note.md

  [[ "${status}" -ne 0 ]]
  [[ "${output}" == *"QFB_TOKEN is not set"* ]]
  [[ ! -e "${QFB_TEST_DIR}/requests.jsonl" ]]
}

@test "qfb: setup checks configuration without making a request or printing the token" {
  run blobs setup

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"No local setup is needed"* ]]
  [[ "${output}" != *"${QFB_TOKEN}"* ]]
  [[ ! -e "${QFB_TEST_DIR}/requests.jsonl" ]]
}

@test "qfb: welcome shows configuration without making a request or printing the token" {
  run blobs welcome

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Backend: qfb"* ]]
  [[ "${output}" != *"${QFB_TOKEN}"* ]]
  [[ ! -e "${QFB_TEST_DIR}/requests.jsonl" ]]
}

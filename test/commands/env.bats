#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "env: requires an explicit backend before contacting storage" {
  unset BLOB_BACKEND

  run blobs list

  [ "$status" -ne 0 ]
  [[ "$output" == *"BLOB_BACKEND is required"* ]]
  [ ! -e "$storage_dir/requests.log" ]
  [ ! -e "$storage_dir/requests.jsonl" ]
}

@test "env: rejects an unknown backend before contacting storage" {
  export BLOB_BACKEND=unknown

  run blobs list

  [ "$status" -ne 0 ]
  [[ "$output" == *"BLOB_BACKEND must be s3 or qfb"* ]]
  [ ! -e "$storage_dir/requests.log" ]
  [ ! -e "$storage_dir/requests.jsonl" ]
}

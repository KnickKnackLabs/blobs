#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "delete: removes a file and reports success" {
  run blobs delete 'sessions/old note.md'

  [ "$status" -eq 0 ]
  [[ "$output" == *"Deleted: sessions/old note.md"* ]]
}

@test "delete: a failed request returns nonzero without reporting success" {
  touch "$storage_dir/request-fails"

  run blobs delete sessions/note.md

  [ "$status" -ne 0 ]
  [[ "$output" != *"Deleted:"* ]]
}

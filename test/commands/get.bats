#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "get: streams file contents to stdout without a status message" {
  run blobs get 'sessions/note & plan.md'

  [ "$status" -eq 0 ]
  [ "$output" = "sample document" ]
}

@test "get: writes exact bytes to a destination with spaces" {
  destination="$BATS_TEST_TMPDIR/downloaded note.md"
  printf 'example\000binary\n' > "$storage_dir/responses/download"

  run blobs get sessions/note.md "$destination"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloaded: sessions/note.md"* ]]
  cmp "$storage_dir/responses/download" "$destination"
}

#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_s3_env
}

@test "s3: get to stdout uses mc cat with the full target" {
  run blobs get sessions/note.md

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "cat test/test-bucket/sessions/note.md" ]
}

@test "s3: get to a file uses quiet mc cp" {
  destination="$BATS_TEST_TMPDIR/note.md"

  run blobs get sessions/note.md "$destination"

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "cp -q test/test-bucket/sessions/note.md $destination" ]
}

@test "s3: put a file uses quiet mc cp" {
  source="$BATS_TEST_TMPDIR/note.md"
  printf 'hello\n' > "$source"

  run blobs put sessions/note.md "$source"

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "cp -q $source test/test-bucket/sessions/note.md" ]
}

@test "s3: put from stdin uses quiet mc pipe" {
  run bash -c 'printf "streamed" | blobs put sessions/note.md'

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "pipe -q test/test-bucket/sessions/note.md" ]
}

@test "s3: list without a prefix targets the bucket root" {
  run blobs list

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls test/test-bucket" ]
}

@test "s3: list appends a prefix to the target" {
  run blobs list sessions/

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls test/test-bucket/sessions/" ]
}

@test "s3: list forwards the JSON flag" {
  run blobs list --json

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls --json test/test-bucket" ]
}

@test "s3: list forwards the recursive flag" {
  run blobs list --recursive

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls --recursive test/test-bucket" ]
}

@test "s3: list translates the short recursive flag" {
  run blobs list -r

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls --recursive test/test-bucket" ]
}

@test "s3: list combines a prefix and the recursive flag" {
  run blobs list --recursive sessions/

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls --recursive test/test-bucket/sessions/" ]
}

@test "s3: list combines JSON, recursion, and a prefix" {
  run blobs list --json --recursive sessions/

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "ls --json --recursive test/test-bucket/sessions/" ]
}

@test "s3: delete uses mc rm with the full target" {
  run blobs delete sessions/old.md

  [ "$status" -eq 0 ]
  [ "$(last_mc_call)" = "rm test/test-bucket/sessions/old.md" ]
}

@test "s3: operations require B2_ALIAS" {
  unset B2_ALIAS

  run blobs list

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_ALIAS is not set"* ]]
}

@test "s3: operations require B2_BUCKET" {
  unset B2_BUCKET

  run blobs list

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_BUCKET is not set"* ]]
}

@test "s3: operations require a configured mc alias" {
  clear_mc_alias

  run blobs list

  [ "$status" -ne 0 ]
  [[ "$output" == *"mc alias 'test' not configured"* ]]
  [[ "$output" == *"blobs setup"* ]]
}

@test "s3: setup creates an alias using the supplied credentials" {
  clear_mc_alias

  run blobs setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"Blob storage configured"* ]]
  [ "$(last_mc_call)" = "alias set test https://s3.example.test fictional-key-id fictional-application-key --api s3v4" ]
}

@test "s3: setup adds https when the endpoint has no scheme" {
  clear_mc_alias
  export B2_ENDPOINT="s3.example.test"

  run blobs setup

  [ "$status" -eq 0 ]
  [[ "$(last_mc_call)" == *"https://s3.example.test"* ]]
}

@test "s3: setup requires B2_ALIAS" {
  unset B2_ALIAS

  run blobs setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_ALIAS"* ]]
}

@test "s3: setup requires B2_ENDPOINT" {
  unset B2_ENDPOINT

  run blobs setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_ENDPOINT"* ]]
}

@test "s3: setup requires B2_KEY_ID" {
  unset B2_KEY_ID

  run blobs setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_KEY_ID"* ]]
}

@test "s3: setup requires B2_APPLICATION_KEY" {
  unset B2_APPLICATION_KEY

  run blobs setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_APPLICATION_KEY"* ]]
}

@test "s3: setup reports missing credentials together" {
  unset B2_ENDPOINT B2_KEY_ID B2_APPLICATION_KEY

  run blobs setup

  [ "$status" -ne 0 ]
  [[ "$output" == *"B2_ENDPOINT"* ]]
  [[ "$output" == *"B2_KEY_ID"* ]]
  [[ "$output" == *"B2_APPLICATION_KEY"* ]]
}

@test "s3: setup leaves an existing alias unchanged" {
  run blobs setup

  [ "$status" -eq 0 ]
  [[ "$output" == *"already configured"* ]]
  [ "$(all_mc_calls)" = "alias list test" ]
}

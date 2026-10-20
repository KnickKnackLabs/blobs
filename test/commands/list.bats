#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  load ../test_helper
  setup_command_env
}

@test "list: without a path shows root files and folders" {
  run blobs list

  [ "$status" -eq 0 ]
  [[ "$output" == *"index.md"* ]]
  [[ "$output" == *"sessions/"* ]]
  [[ "$output" != *"note & plan.md"* ]]
}

@test "list: a directory path selects its contents" {
  run blobs list sessions/

  [ "$status" -eq 0 ]
  [[ "$output" == *"note & plan.md"* ]]
  [[ "$output" != *"index.md"* ]]
}

@test "list: JSON records contain a key and a type" {
  run blobs list --json

  [ "$status" -eq 0 ]
  records=$(printf '%s\n' "$output" | jq -s '.')
  [ "$(printf '%s' "$records" | jq 'length')" -eq 2 ]
  printf '%s' "$records" | jq -e 'all(.[]; (.key | type == "string") and (.type | type == "string"))'
}

@test "list: recursive output includes files in child directories" {
  run blobs list --recursive

  [ "$status" -eq 0 ]
  [[ "$output" == *"index.md"* ]]
  [[ "$output" == *"sessions/note & plan.md"* ]]
}

@test "list: the short recursive flag includes child files" {
  run blobs list -r

  [ "$status" -eq 0 ]
  [[ "$output" == *"sessions/note & plan.md"* ]]
}

@test "list: JSON and recursive flags work together within a directory" {
  run blobs list --json --recursive sessions/

  [ "$status" -eq 0 ]
  key=$(printf '%s\n' "$output" | jq -r '.key')
  [[ "$key" == *"note & plan.md" ]]
  [ "$(printf '%s\n' "$output" | jq -r '.type')" = file ]
}

@test "list: ignores inherited optional usage values" {
  export usage_prefix="stale/"
  export usage_json="true"
  export usage_recursive="true"

  run blobs list

  [ "$status" -eq 0 ]
  [[ "$output" == *"index.md"* ]]
  [[ "$output" == *"sessions/"* ]]
  [[ "$output" != *"note & plan.md"* ]]
  [[ "$output" != *'"key"'* ]]
}

BLOBS_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOBS_REPO_DIR="$(cd "${BLOBS_TEST_ROOT}/.." && pwd)"
export BLOBS_REPO_DIR

blobs() {
  (cd "${BLOBS_REPO_DIR}" && mise run -q "$@")
}
export -f blobs

setup_state() {
  export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
  mise trust "${BLOBS_REPO_DIR}/mise.toml"
}

setup_mocks() {
  export MC="${BLOBS_TEST_ROOT}/mocks/mc"
  export CURL="${BLOBS_TEST_ROOT}/mocks/curl"

  export BLOBS_TEST_ETAG="fictional-etag"
  export BLOBS_TEST_EXISTS="true"
}

setup_s3_env() {
  setup_state

  export BLOB_BACKEND=s3
  export B2_ALIAS=test
  export B2_BUCKET=test-bucket
  export B2_ENDPOINT=https://s3.example.test
  export B2_KEY_ID=fictional-key-id
  export B2_APPLICATION_KEY=fictional-application-key

  setup_mocks

  export S3_TEST_DIR="${BATS_TEST_TMPDIR}/s3"
  mkdir -p "${S3_TEST_DIR}"
  printf 'test\n' > "${S3_TEST_DIR}/alias"
  cp -R "${BLOBS_TEST_ROOT}/fixtures/s3/responses" "${S3_TEST_DIR}/responses"
}

setup_qfb_env() {
  setup_state

  export BLOB_BACKEND=qfb
  export QFB_URL="https://files.example.test"
  export QFB_SOURCE="Shared files"
  export QFB_TOKEN="fictional-test-token"

  setup_mocks

  export QFB_TEST_DIR="${BATS_TEST_TMPDIR}/qfb"
  mkdir -p "${QFB_TEST_DIR}"
  cp -R "${BLOBS_TEST_ROOT}/fixtures/qfb/responses" "${QFB_TEST_DIR}/responses"
}

# Shared command suites read storage_dir after setup returns.
# shellcheck disable=SC2034
setup_command_env() {
  case "${BLOBS_TEST_BACKEND:?Run shared command tests through mise run test}" in
    s3)
      setup_s3_env
      storage_dir="$S3_TEST_DIR"
      ;;

    qfb)
      setup_qfb_env
      storage_dir="$QFB_TEST_DIR"
      ;;

    *) echo "Unknown test backend: $BLOBS_TEST_BACKEND" >&2; return 1 ;;
  esac
}

clear_mc_alias() {
  : > "$S3_TEST_DIR/alias"
}

last_mc_call() {
  tail -n 1 "$S3_TEST_DIR/requests.log"
}

all_mc_calls() {
  cat "$S3_TEST_DIR/requests.log"
}

last_curl_call() {
  tail -n 1 "$QFB_TEST_DIR/requests.jsonl"
}

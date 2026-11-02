# blobs

**Put, get, list, and delete files in S3-compatible storage or FileBrowser Quantum.**
Choose a backend with `BLOB_BACKEND=s3` or `BLOB_BACKEND=qfb`. It is required;
blobs never chooses a storage account for you.

```sh
blobs put sessions/note.md ./note.md
blobs get sessions/note.md                 # stdout
blobs get sessions/note.md ./download.md   # local file
blobs list sessions/
blobs list --recursive --json sessions/
blobs delete sessions/note.md
```

`put` creates or replaces a file. Omit the local filename, or use `-`, to read
from stdin. Paths are relative to the configured bucket or QFB user's source root.

There's some half-assed remote overwrite protection, using etags from the provider. It warns if a changed remote file is detected, and requires `--force` to overwrite.

## Install

```sh
shiv install blobs
```

## FileBrowser Quantum

Provide the server URL, source name, and an existing API token through your
environment:

```sh
export BLOB_BACKEND=qfb
export QFB_URL=https://files.example.test
export QFB_SOURCE=Shared
# Set QFB_TOKEN through your normal secret-loading mechanism.

blobs welcome
blobs list
blobs get 'Clients/Example/Sessions/2026-10-06/note.md'
```

The URL is the FileBrowser base URL, without `/api`. A base path is supported,
for example `https://files.example.test/filebrowser`. The source name must match
one available to the token's user. QFB enforces that user's scope and permissions.
Keep the token out of committed configuration files.

QFB needs no one-time local setup. `setup` checks configuration; `welcome` shows
it without reading files or printing the token. Neither verifies server access.

For QFB, `list` takes a **directory**, not a partial filename prefix. Plain output
contains root-relative paths, with `/` after folders. `--recursive` walks folders
and lists files only. `--json` emits one record per line:

```json
{"key":"sessions/note.md","type":"file"}
{"key":"sessions/next","type":"folder"}
```

`delete` rejects directories. It reads the resource's metadata before deleting
an individual file.

## S3-compatible storage

The S3 backend uses `mc`, with Backblaze B2 as the reference service. Existing
`B2_*` variable names are retained.

```sh
export BLOB_BACKEND=s3
export B2_ALIAS=work
export B2_BUCKET=my-bucket
export B2_ENDPOINT=https://s3.us-east-005.backblazeb2.com
# Set B2_KEY_ID and B2_APPLICATION_KEY through your secret-loading mechanism.
blobs setup

blobs put notes/hello.txt ./hello.txt
blobs list notes/
```

`setup` stores an `mc` alias in `~/.mc/config.json` and leaves an existing alias
unchanged. Daily operations need only `BLOB_BACKEND`, `B2_ALIAS`, and `B2_BUCKET`.
Use different aliases and buckets for different accounts.

S3 listing retains `mc`'s output and key-prefix matching, including its richer
JSON records. The JSON fields are not identical across backends; both include
`key` and `type`.

## Code layout

Public tasks parse arguments and call `blob_get`, `blob_put`, `blob_list`, etc.
`.mise/tasks/_env` sources exactly one implementation:

```text
.mise/lib/backends/
├── s3.sh     # mc operations and alias setup
└── qfb.sh    # curl requests and directory traversal
```

## Development

```sh
mise trust
mise install
mise run test                 # all checks
mise run test put             # put contract against both backends
mise run test qfb             # QFB-specific checks
mise run test --filter stdin
```

`test/commands/` checks shared CLI behavior against both S3 and QFB.
`test/backends/` checks backend configuration and the arguments sent to `mc`
and `curl`. Both suites invoke the public Mise tasks with recording doubles;
they use fictional fixtures under `test/fixtures/` and never access storage.
Each backend has its own setup and scratch directory. `MC` and `CURL` override
the executables for testing.

## License

MIT

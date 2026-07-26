# Person-record CLI fixture

This is a verbatim test-local copy of Garden's authored
`shacl-core-person-record` data and shapes inputs as of 2026-07-26. It keeps
the component CI self-contained while Garden remains the authoritative
cross-project fixture and release-qualified gate.

Expected command behavior: `odin validate` emits four sorted violations and
exits with status 1.

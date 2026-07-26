# Changelog

This project follows [Semantic Versioning](https://semver.org/).

## Unreleased

- Add the proposed `odin query` workflow: bounded local Turtle ingestion into
  `odin-sparql v0.7.0`'s RDF-only `Memory_Dataset`, bounded local `.rq` input,
  deterministic standard result formats, and exit status 0/2 for completed or
  failed query work. It deliberately excludes named-graph input, inference,
  Update, endpoint serving, Graph dependency, and all network I/O.

## 0.1.0 - 2026-07-26

- Add `odin validate`: bounded local Turtle data and shapes parsing, released
  SHACL Core validation, deterministic JSON output, and conventional exit
  statuses for conforms, violations, and operational/profile errors.

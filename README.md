# odin-cli

[![Workflow](https://img.shields.io/badge/workflow-local_validation-2563eb)](docs/validate.md)
![Platforms](https://img.shields.io/badge/platforms-Linux_%7C_macOS_%7C_Windows-475569)
[![License: MIT](https://img.shields.io/badge/license-MIT-f59e0b)](LICENSE)

`odin-cli` is the deliberately thin application layer for stable Odin semantic
workflows. Its first command turns released RDF parsing and SHACL validation
into one local-file operation without exposing either component's internals.

## `odin validate`

```sh
odin validate \
  --data person-data.ttl \
  --shapes person-shapes.ttl \
  --max-data-triples 100000 \
  --max-shapes-triples 100000 \
  --max-results 10000
```

The command reads two local Turtle files, emits one deterministic JSON report
on standard output, and uses these exit statuses:

| Status | Meaning |
| ---: | --- |
| 0 | The data conforms to the supported SHACL profile. |
| 1 | Validation completed and produced one or more results. |
| 2 | Command parsing, local I/O, Turtle parsing, resource admission, shape-profile, or output error. |

It does not perform inference, query execution, graph persistence, HTTP, URL
loading, or implicit network access. The current workflow is intentionally
Turtle-only and standard-output-only. See the [validate contract](docs/validate.md)
and [JSON report schema](docs/validate-report-schema.md).

## Compatibility

Version 0.1 is built against `odin-rdf v0.33.0` and `odin-shacl v0.1.0`.
Those components retain their own public contracts; this repository owns only
argument handling, local-file admission, JSON rendering, and exit status.
Applications should pin releases and retain an end-to-end test for their own
data and shapes.

## Development

With sibling checkouts of the released component sources:

```sh
odin test cmd/odin -collection:odin-rdf=../odin-rdf -collection:odin-shacl=../odin-shacl
odin check cmd/odin -collection:odin-rdf=../odin-rdf -collection:odin-shacl=../odin-shacl -vet -warnings-as-errors
```

The first user-facing fixture is based on the Garden
[`person-record` validation case](https://github.com/crapthings/odin-garden/tree/main/fixtures/shacl-core/person-record).

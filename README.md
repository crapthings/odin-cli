# odin-cli

[![Workflow](https://img.shields.io/badge/workflow-local_semantic_tools-2563eb)](docs/validate.md)
![Platforms](https://img.shields.io/badge/platforms-Linux_%7C_macOS_%7C_Windows-475569)
[![License: MIT](https://img.shields.io/badge/license-MIT-f59e0b)](LICENSE)

`odin-cli` is the deliberately thin application layer for stable Odin semantic
workflows. It turns released RDF parsing, SHACL validation, and SPARQL query
execution into narrow local-file operations without exposing component
internals.

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

## `odin query` (proposed v0.2)

```sh
odin query \
  --data people.ttl \
  --query friends.rq \
  --format json \
  --max-data-triples 100000 \
  --max-query-bytes 1048576 \
  --max-results 10000
```

The command evaluates one local SPARQL Query document over one local Turtle
default graph. By default, SELECT and ASK produce SPARQL Results JSON, while
graph results produce N-Triples. XML, CSV, TSV, and Turtle are explicit
compatible alternatives. A completed query, including an empty result, exits
0; command, input, limit, execution, and serializer failures exit 2.

`odin query` uses only the released `odin-rdf` and `odin-sparql v0.7.0` core
boundary. It does not require Graph, inference, a database, network I/O,
SERVICE resolution, named-graph input, SPARQL Update, or persistence. See the
[query contract](docs/query.md) for exact limits and output rules.

## Compatibility

Version 0.1 is built against `odin-rdf v0.33.0` and `odin-shacl v0.1.0`.
The proposed v0.2 query workflow additionally pins `odin-sparql v0.7.0`.
Those components retain their own public contracts; this repository owns
argument handling, local-file admission, bounded Dataset setup, serialization,
and exit status. Applications should pin releases and retain an end-to-end test
for their own data, shapes, and queries.

## Development

With sibling checkouts of the released component sources:

```sh
odin test cmd/odin -collection:odin-rdf=../odin-rdf -collection:odin-shacl=../odin-shacl -collection:odin-sparql=../odin-sparql
odin check cmd/odin -collection:odin-rdf=../odin-rdf -collection:odin-shacl=../odin-shacl -collection:odin-sparql=../odin-sparql -vet -warnings-as-errors
```

The first user-facing fixture is based on the Garden
[`person-record` validation case](https://github.com/crapthings/odin-garden/tree/main/fixtures/shacl-core/person-record).
The query fixture is local and will be Garden-qualified against the released
RDF/SPARQL pair before a v0.2 tag is proposed.

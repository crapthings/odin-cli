# `odin validate` contract, version 0.1

## Invocation

```text
odin validate --data DATA.ttl --shapes SHAPES.ttl
  [--max-data-triples N]
  [--max-shapes-triples N]
  [--max-statement-bytes N]
  [--max-results N]
```

`--data` and `--shapes` are each required exactly once. They are ordinary local
file paths; `-` is rejected so that no workflow attempts to consume two
ambiguous standard-input streams. The files are parsed as Turtle with no base
IRI supplied by the CLI. A relative IRI in either file therefore remains a
Turtle parse error unless the document declares an absolute base itself.

Every limit is a positive decimal integer. Defaults are 100,000 data triples,
100,000 shape triples, 16 MiB per top-level Turtle statement, and 10,000 report
results. The parser and retained application-owned triple collections both
enforce the corresponding triple limits.

## Processing and ownership

The command parses data and shapes through `odin-rdf`, copies parser callback
terms into bounded application-owned collections, validates them through
`odin-shacl`, then destroys both input collections before rendering output.
The validator report owns its result terms, so JSON rendering does not depend
on parser-buffer or collection lifetime.

Validation is the bounded SHACL Core profile from `odin-shacl v0.1.0`. The CLI
does not add inference or expand the profile. An unsupported shape is a command
error, not a conforming empty report.

## Output and exits

On a completed validation, standard output receives exactly one newline-ended
JSON report matching [validate-report-schema.md](validate-report-schema.md).
The report is deterministic because `odin-shacl` sorts results before returning
them. Diagnostics go to standard error; successful and violation results do
not add prose to standard output.

- Exit 0: `conforms` is true.
- Exit 1: `conforms` is false and `results` is nonempty.
- Exit 2: invalid arguments, local file failure, Turtle error, configured
  limit, malformed/unsupported SHACL, allocation failure, or JSON-output
  failure. No partial JSON report is emitted on this path.

There is no output-file option, network option, remote context, URL loader,
RDFS/OWL materialization, SPARQL query, named-graph input, or persistence
behavior in version 0.1.

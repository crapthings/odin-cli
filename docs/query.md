# `odin query` contract, proposed version 0.2

## Invocation

```text
odin query --data DATA.ttl --query QUERY.rq
  [--format auto|json|xml|csv|tsv|nt|turtle]
  [--max-data-triples N]
  [--max-statement-bytes N]
  [--max-query-bytes N]
  [--max-results N]
```

`--data` and `--query` are each required exactly once. They are ordinary local
file paths; `-` is rejected. `DATA.ttl` is parsed as Turtle into the default
graph only. The command does not admit named-graph files, fetch a `FROM` or
`FROM NAMED` IRI, or supply a `SERVICE` callback.

Every limit is a positive decimal integer. The defaults are 100,000 parsed data
triples, 16 MiB per top-level Turtle statement, 1 MiB for the query document,
and 10,000 materialized solutions. The query byte check runs before parsing;
the Turtle parser and the Dataset admission boundary each enforce the data
limit.

## Processing and ownership

The command parses Turtle through `odin-rdf`, then copies each accepted triple
into `odin-sparql v0.7.0`'s bounded `Memory_Dataset`. It destroys the
parser-owned collection before parsing or evaluating the SPARQL document.
After sealing, the Dataset is a borrowed read-only View for one execution; the
engine owns its result and the selected serializer writes it to standard output.

The core path depends only on `odin-rdf` and `odin-sparql`. It does not require
`odin-graph`, a database, a reasoner, an HTTP client, a remote-context loader,
or a persistent store. A query with `SERVICE` has no remote resolver available;
the command never performs implicit I/O beyond its two local input files.

## Output and exits

`--format auto` is the default:

| Result kind | `auto` output | Explicit accepted formats |
| --- | --- | --- |
| SELECT / ASK | SPARQL Results JSON | `json`, `xml`, `csv`, `tsv` |
| Graph result | N-Triples | `nt`, `ntriples`, `turtle` |

Choosing a bindings format for a graph result, or a graph format for SELECT or
ASK, is an error and produces no partial result. Serializers retain their
document-specific deterministic blank-node labeling policy.

- Exit 0: query parsed, evaluated, and serialized successfully, including an
  empty SELECT result or a false ASK result.
- Exit 2: invalid arguments, local-file failure, query-byte limit, Turtle or
  SPARQL parse error, Dataset admission error, query execution error, or result
  serialization error. No partial standard output is emitted on this path.

The workflow deliberately does not perform inference, SPARQL Update, named
graph ingestion, endpoint serving, output-file handling, or persistence.

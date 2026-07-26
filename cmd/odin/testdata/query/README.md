# Local query fixture

This fixture fixes the first `odin query` contract: one local Turtle data graph
and one local SPARQL Query document. It contains no remote context, endpoint,
SERVICE callback, graph-store, or inference input.

`select.rq` proves deterministic SPARQL Results JSON ordering. `construct.rq`
proves the graph-result default of N-Triples. Both query only the default graph.

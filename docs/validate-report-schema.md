# `odin validate` JSON report schema, version 0.1

The command writes one object with this shape:

```json
{
  "conforms": false,
  "results": [
    {
      "focusNode": {"type": "iri", "value": "https://example.org/bea"},
      "resultPath": {"type": "iri", "value": "https://example.org/email"},
      "value": {"type": "literal", "value": "not-an-iri"},
      "sourceShape": {"type": "iri", "value": "https://example.org/EmailShape"},
      "sourceConstraintComponent": "nodeKind",
      "severity": "violation"
    }
  ]
}
```

`value` is omitted for count constraints. All other result fields are present.
`severity` is always `"violation"` in the underlying first SHACL profile.
`sourceConstraintComponent` is one of `"minCount"`, `"maxCount"`,
`"datatype"`, or `"nodeKind"`.

Every term object has a `type` and `value` field. `type` is `"iri"`,
`"blankNode"`, or `"literal"`. Literal terms additionally have `language`
when language-tagged, otherwise `datatype` when its datatype is not
`xsd:string`. This is a CLI rendering schema, not an RDF serialization or a
claim of full SHACL validation-report graph serialization.

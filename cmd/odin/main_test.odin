package main

import "core:strings"
import "core:testing"
import rdf "odin-rdf:rdf"
import validator "odin-shacl:shacl"

GARDEN_DATA   :: "../odin-garden/fixtures/shacl-core/person-record/data.ttl"
GARDEN_SHAPES :: "../odin-garden/fixtures/shacl-core/person-record/shapes.ttl"

@(test)
test_parse_validate_args_requires_two_regular_local_paths :: proc(t: ^testing.T) {
	options, error := parse_args([]string{"validate", "--data", "data.ttl", "--shapes=shapes.ttl", "--max-results", "9"})
	testing.expect_value(t, error.code, Command_Error_Code.None)
	testing.expect_value(t, options.data_path, "data.ttl")
	testing.expect_value(t, options.shapes_path, "shapes.ttl")
	testing.expect_value(t, options.max_results, 9)

	_, error = parse_args([]string{"validate", "--data", "-", "--shapes", "shapes.ttl"})
	testing.expect_value(t, error.code, Command_Error_Code.Invalid_Path)
	_, error = parse_args([]string{"validate", "--data", "data.ttl", "--shapes", "shapes.ttl", "--max-results", "0"})
	testing.expect_value(t, error.code, Command_Error_Code.Invalid_Limit)
	_, error = parse_args([]string{"validate", "--data", "data.ttl", "--data", "other.ttl", "--shapes", "shapes.ttl"})
	testing.expect_value(t, error.code, Command_Error_Code.Duplicate_Data)
}

@(test)
test_person_record_fixture_returns_stable_machine_report_and_violation_exit :: proc(t: ^testing.T) {
	options := Options{
		data_path = GARDEN_DATA,
		shapes_path = GARDEN_SHAPES,
		max_data_triples = 32,
		max_shapes_triples = 32,
		max_statement_bytes = DEFAULT_MAX_STATEMENT_BYTES,
		max_results = 8,
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	exit_code, detail := run_validate(options, &builder)
	testing.expect_value(t, exit_code, Exit_Violations)
	testing.expect_value(t, detail, "")
	output := strings.to_string(builder)
	testing.expect(t, strings.has_prefix(output, `{"conforms":false,"results":[`))
	testing.expect(t, strings.contains(output, `"sourceConstraintComponent":"nodeKind"`))
	testing.expect(t, strings.contains(output, `"sourceConstraintComponent":"datatype"`))
	testing.expect(t, strings.contains(output, `"sourceConstraintComponent":"minCount"`))
	testing.expect(t, strings.contains(output, `"sourceConstraintComponent":"maxCount"`))
	bea := strings.index(output, `"value":"not-an-iri"`)
	cora := strings.index(output, `"value":"ID-2"`)
	testing.expect(t, bea >= 0 && cora > bea)
}

@(test)
test_report_json_escapes_literal_values :: proc(t: ^testing.T) {
	person := rdf.iri("https://example.org/Person")
	node := rdf.iri("https://example.org/node")
	email := rdf.iri("https://example.org/email")
	person_shape := rdf.iri("https://example.org/PersonShape")
	email_shape := rdf.iri("https://example.org/EmailShape")
	data := [2]rdf.Triple{
		{node, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), person},
		{node, email, rdf.literal("quote: \" newline: \n")},
	}
	shapes := [5]rdf.Triple{
		{person_shape, rdf.iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"), rdf.iri("http://www.w3.org/ns/shacl#NodeShape")},
		{person_shape, rdf.iri("http://www.w3.org/ns/shacl#targetClass"), person},
		{person_shape, rdf.iri("http://www.w3.org/ns/shacl#property"), email_shape},
		{email_shape, rdf.iri("http://www.w3.org/ns/shacl#path"), email},
		{email_shape, rdf.iri("http://www.w3.org/ns/shacl#nodeKind"), rdf.iri("http://www.w3.org/ns/shacl#IRI")},
	}
	report: validator.Report
	defer validator.destroy(&report)
	testing.expect_value(t, validator.validate(data[:], shapes[:], &report), validator.Error_Code.None)
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	testing.expect(t, write_report_json(&builder, &report))
	output := strings.to_string(builder)
	testing.expect(t, strings.contains(output, `quote: \" newline: \n`))
}

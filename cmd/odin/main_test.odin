package main

import "core:strings"
import "core:testing"
import rdf "odin-rdf:rdf"
import validator "odin-shacl:shacl"

GARDEN_DATA   :: "cmd/odin/testdata/person-record/data.ttl"
GARDEN_SHAPES :: "cmd/odin/testdata/person-record/shapes.ttl"
QUERY_DATA    :: "cmd/odin/testdata/query/data.ttl"
QUERY_SELECT  :: "cmd/odin/testdata/query/select.rq"
QUERY_CONSTRUCT :: "cmd/odin/testdata/query/construct.rq"

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
test_parse_query_args_requires_local_data_and_query_with_a_result_format :: proc(t: ^testing.T) {
	options, error := parse_args([]string{"query", "--data", "data.ttl", "--query=query.rq", "--format", "tsv", "--max-data-triples", "9", "--max-query-bytes", "128"})
	testing.expect_value(t, error.code, Command_Error_Code.None)
	testing.expect_value(t, options.command, Command.Query)
	testing.expect_value(t, options.data_path, "data.ttl")
	testing.expect_value(t, options.query_path, "query.rq")
	testing.expect_value(t, options.format, Query_Format.TSV)
	testing.expect_value(t, options.max_data_triples, 9)
	testing.expect_value(t, options.max_query_bytes, 128)

	_, error = parse_args([]string{"query", "--data", "data.ttl"})
	testing.expect_value(t, error.code, Command_Error_Code.Missing_Query)
	_, error = parse_args([]string{"query", "--data", "-", "--query", "query.rq"})
	testing.expect_value(t, error.code, Command_Error_Code.Invalid_Path)
	_, error = parse_args([]string{"query", "--data", "data.ttl", "--query", "query.rq", "--format", "yaml"})
	testing.expect_value(t, error.code, Command_Error_Code.Invalid_Format)
	_, error = parse_args([]string{"query", "--data", "data.ttl", "--query", "query.rq", "--shapes", "shapes.ttl"})
	testing.expect_value(t, error.code, Command_Error_Code.Unknown_Option)
}

@(test)
test_local_query_fixture_returns_deterministic_select_and_construct_results :: proc(t: ^testing.T) {
	select_options := Options{
		command = .Query,
		data_path = QUERY_DATA,
		query_path = QUERY_SELECT,
		max_data_triples = 16,
		max_statement_bytes = DEFAULT_MAX_STATEMENT_BYTES,
		max_results = 8,
		max_query_bytes = 1024,
		format = .Auto,
	}
	select_output := strings.builder_make()
	defer strings.builder_destroy(&select_output)
	exit_code, detail := run_query(select_options, &select_output)
	testing.expect_value(t, exit_code, Exit_Conforms)
	testing.expect_value(t, detail, "")
	testing.expect_value(t, strings.to_string(select_output), `{"head":{"vars":["friend"]},"results":{"bindings":[{"friend":{"type":"uri","value":"urn:bert"}},{"friend":{"type":"uri","value":"urn:cora"}}]}}`)

	construct_options := select_options
	construct_options.query_path = QUERY_CONSTRUCT
	construct_output := strings.builder_make()
	defer strings.builder_destroy(&construct_output)
	exit_code, detail = run_query(construct_options, &construct_output)
	testing.expect_value(t, exit_code, Exit_Conforms)
	testing.expect_value(t, detail, "")
	testing.expect_value(t, strings.to_string(construct_output), "<urn:ada> <urn:relatedTo> <urn:bert> .\n<urn:ada> <urn:relatedTo> <urn:cora> .\n")
}

@(test)
test_local_query_rejects_a_query_document_over_its_explicit_bound :: proc(t: ^testing.T) {
	options := Options{
		command = .Query,
		data_path = QUERY_DATA,
		query_path = QUERY_SELECT,
		max_data_triples = 16,
		max_statement_bytes = DEFAULT_MAX_STATEMENT_BYTES,
		max_results = 8,
		max_query_bytes = 4,
		format = .Auto,
	}
	output := strings.builder_make()
	defer strings.builder_destroy(&output)
	exit_code, detail := run_query(options, &output)
	testing.expect_value(t, exit_code, Exit_Error)
	testing.expect_value(t, detail, "query byte limit reached")
}

@(test)
test_local_query_uses_explicit_result_formats_without_partial_mismatches :: proc(t: ^testing.T) {
	select_options := Options{
		command = .Query,
		data_path = QUERY_DATA,
		query_path = QUERY_SELECT,
		max_data_triples = 16,
		max_statement_bytes = DEFAULT_MAX_STATEMENT_BYTES,
		max_results = 8,
		max_query_bytes = 1024,
		format = .TSV,
	}
	tsv_output := strings.builder_make()
	defer strings.builder_destroy(&tsv_output)
	exit_code, detail := run_query(select_options, &tsv_output)
	testing.expect_value(t, exit_code, Exit_Conforms)
	testing.expect_value(t, detail, "")
	testing.expect_value(t, strings.to_string(tsv_output), "?friend\n<urn:bert>\n<urn:cora>\n")

	graph_options := select_options
	graph_options.query_path = QUERY_CONSTRUCT
	graph_options.format = .JSON
	graph_output := strings.builder_make()
	defer strings.builder_destroy(&graph_output)
	exit_code, detail = run_query(graph_options, &graph_output)
	testing.expect_value(t, exit_code, Exit_Error)
	testing.expect_value(t, detail, "result is not a SELECT or ASK result")
	testing.expect_value(t, strings.to_string(graph_output), "")
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

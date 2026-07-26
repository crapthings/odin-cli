// The local query workflow deliberately accepts one bounded Turtle graph and
// one bounded SPARQL query document. It never opens a network connection,
// invokes SERVICE callbacks, or creates a persistent store.
package main

import "core:os"
import "core:strings"
import rdf "odin-rdf:rdf"
import turtle "odin-rdf:rdf/turtle"
import sparql "odin-sparql:sparql"
import dataset "odin-sparql:sparql/dataset"
import engine "odin-sparql:sparql/engine"
import results "odin-sparql:sparql/results"

Query_Format :: enum { Auto, JSON, XML, CSV, TSV, NTriples, Turtle }

parse_query_format :: proc(value: string) -> (Query_Format, bool) {
	switch value {
	case "auto":     return .Auto, true
	case "json":     return .JSON, true
	case "xml":      return .XML, true
	case "csv":      return .CSV, true
	case "tsv":      return .TSV, true
	case "nt", "ntriples": return .NTriples, true
	case "turtle":   return .Turtle, true
	}
	return .Auto, false
}

read_query_file :: proc(path: string, max_bytes: int) -> (data: []u8, detail: string) {
	input, open_error := os.open(path)
	if open_error != nil do return nil, "cannot open query file"
	defer _ = os.close(input)
	size, size_error := os.file_size(input)
	if size_error != nil do return nil, "cannot inspect query file"
	if size < 0 || size > i64(max_bytes) do return nil, "query byte limit reached"
	read_error: os.Error
	data, read_error = os.read_entire_file(input, context.allocator)
	if read_error != nil do return nil, "cannot read query file"
	if len(data) > max_bytes {
		delete(data)
		return nil, "query byte limit reached"
	}
	return data, ""
}

write_query_result :: proc(builder: ^strings.Builder, format: Query_Format, result: ^engine.Result) -> results.Error_Code {
	switch format {
	case .Auto:
		if engine.Kind(result) == .Graph do return results.write_ntriples(builder, result)
		return results.write_sparql_json(builder, result)
	case .JSON:     return results.write_sparql_json(builder, result)
	case .XML:      return results.write_sparql_xml(builder, result)
	case .CSV:      return results.write_sparql_csv(builder, result)
	case .TSV:      return results.write_sparql_tsv(builder, result)
	case .NTriples: return results.write_ntriples(builder, result)
	case .Turtle:   return results.write_turtle(builder, result)
	}
	return .Not_Bindings_Result
}

run_query :: proc(options: Options, builder: ^strings.Builder) -> (exit_code: int, detail: string) {
	input: Owned_Triples
	input_error := load_turtle(options.data_path, options.max_data_triples, options.max_statement_bytes, &input)
	if input_error.open_error != nil do return Exit_Error, "cannot open data file"
	if input_error.limit { destroy_owned(&input); return Exit_Error, "data triple limit reached" }
	if input_error.parse_error.code != .None { destroy_owned(&input); return Exit_Error, turtle.parse_error_message(input_error.parse_error.code) }
	defer destroy_owned(&input)

	store: dataset.Memory_Dataset
	store_error := dataset.init_with_options(&store, {Max_Quads = options.max_data_triples})
	if store_error != .None do return Exit_Error, dataset.error_message(store_error)
	defer dataset.destroy(&store)
	for triple in input.triples {
		store_error = dataset.add(&store, rdf.default_graph_quad(triple))
		if store_error != .None do return Exit_Error, dataset.error_message(store_error)
	}
	// The Dataset has its own copied representation; parser-retained values no
	// longer participate in evaluation or result lifetimes.
	destroy_owned(&input)
	dataset.seal(&store)
	view, view_error := dataset.view(&store)
	if view_error != .None do return Exit_Error, dataset.error_message(view_error)

	query_text, query_detail := read_query_file(options.query_path, options.max_query_bytes)
	if len(query_detail) > 0 do return Exit_Error, query_detail
	defer delete(query_text)
	query, parse_error := sparql.Parse(string(query_text))
	if sparql.Parse_Error_Code(parse_error) != .None do return Exit_Error, sparql.Parse_Error_Message(parse_error)
	defer sparql.Destroy(&query)
	result, execute_error := engine.execute(&query, view, {Max_Solutions = options.max_results})
	if execute_error != .None do return Exit_Error, engine.error_message(execute_error)
	defer engine.destroy(&result)
	if result_error := write_query_result(builder, options.format, &result); result_error != .None do return Exit_Error, results.error_message(result_error)
	return Exit_Conforms, ""
}

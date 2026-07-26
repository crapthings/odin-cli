// odin is the intentionally small application-layer command for released
// Odin semantic workflows. Its first command validates local Turtle files.
package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"
import rdf "odin-rdf:rdf"
import turtle "odin-rdf:rdf/turtle"
import validator "odin-shacl:shacl"

DEFAULT_MAX_TRIPLES         :: 100_000
DEFAULT_MAX_STATEMENT_BYTES :: 16 * 1024 * 1024
DEFAULT_MAX_RESULTS         :: 10_000
DEFAULT_MAX_QUERY_BYTES     :: 1024 * 1024

Exit_Conforms   :: 0
Exit_Violations :: 1
Exit_Error      :: 2

Command :: enum { Validate, Query }

Command_Error_Code :: enum {
	None,
	Missing_Command,
	Unknown_Command,
	Missing_Option_Value,
	Unknown_Option,
	Missing_Data,
	Missing_Shapes,
	Missing_Query,
	Duplicate_Data,
	Duplicate_Shapes,
	Duplicate_Query,
	Invalid_Path,
	Invalid_Limit,
	Invalid_Format,
}

Command_Error :: struct {
	code:  Command_Error_Code,
	value: string,
}

Options :: struct {
	command:             Command,
	data_path:           string,
	shapes_path:         string,
	query_path:          string,
	max_data_triples:    int,
	max_shapes_triples:  int,
	max_statement_bytes: int,
	max_results:         int,
	max_query_bytes:     int,
	format:              Query_Format,
	help:                bool,
}

Load_Error :: struct {
	open_error:  os.Error,
	parse_error: turtle.Parse_Error,
	reader_error: io.Error,
	limit:       bool,
}

Owned_Triples :: struct {
	triples: [dynamic]rdf.Triple,
	owned:   [dynamic]string,
	max:     int,
	limit:   bool,
	error:   bool,
}

error_message :: proc(code: Command_Error_Code) -> string {
	switch code {
	case .None:                 return "no error"
	case .Missing_Command:      return "expected a command"
	case .Unknown_Command:      return "unknown command"
	case .Missing_Option_Value: return "option requires a value"
	case .Unknown_Option:       return "unknown option"
	case .Missing_Data:         return "--data PATH is required"
	case .Missing_Shapes:       return "--shapes PATH is required"
	case .Missing_Query:        return "--query PATH is required"
	case .Duplicate_Data:       return "--data may appear only once"
	case .Duplicate_Shapes:     return "--shapes may appear only once"
	case .Duplicate_Query:      return "--query may appear only once"
	case .Invalid_Path:         return "input paths must be local files, not standard input"
	case .Invalid_Limit:        return "limit must be a positive decimal integer"
	case .Invalid_Format:       return "unsupported result format"
	}
	return "unknown command error"
}

init_owned :: proc(target: ^Owned_Triples, max: int) {
	target^ = Owned_Triples{triples = make([dynamic]rdf.Triple), owned = make([dynamic]string), max = max}
}

destroy_owned :: proc(target: ^Owned_Triples) {
	for value in target.owned do delete(value)
	delete(target.owned)
	delete(target.triples)
	target^ = {}
}

copy_string :: proc(target: ^Owned_Triples, value: string) -> (string, bool) {
	if len(value) == 0 do return "", true
	copy, copy_error := strings.clone(value)
	if copy_error != nil do return "", false
	if _, append_error := append(&target.owned, copy); append_error != nil {
		delete(copy)
		return "", false
	}
	return copy, true
}

copy_term :: proc(target: ^Owned_Triples, source: rdf.Term) -> (rdf.Term, bool) {
	result := source
	valid: bool
	result.value, valid = copy_string(target, source.value)
	if !valid do return {}, false
	result.language, valid = copy_string(target, source.language)
	if !valid do return {}, false
	result.datatype, valid = copy_string(target, source.datatype)
	if !valid do return {}, false
	return result, true
}

triple_sink :: proc(source: rdf.Triple, user_data: rawptr) -> bool {
	target := cast(^Owned_Triples)user_data
	if len(target.triples) >= target.max {
		target.limit = true
		return false
	}
	triple: rdf.Triple
	valid: bool
	triple.subject, valid = copy_term(target, source.subject)
	if !valid { target.error = true; return false }
	triple.predicate, valid = copy_term(target, source.predicate)
	if !valid { target.error = true; return false }
	triple.object, valid = copy_term(target, source.object)
	if !valid { target.error = true; return false }
	if _, append_error := append(&target.triples, triple); append_error != nil {
		target.error = true
		return false
	}
	return true
}

parse_positive_decimal :: proc(value: string) -> (int, bool) {
	if len(value) == 0 do return 0, false
	for byte in value {
		if byte < '0' || byte > '9' do return 0, false
	}
	parsed, valid := strconv.parse_int(value, 10)
	if !valid || parsed <= 0 do return 0, false
	return parsed, true
}

parse_args :: proc(args: []string) -> (Options, Command_Error) {
	options := Options{
		max_data_triples = DEFAULT_MAX_TRIPLES,
		max_shapes_triples = DEFAULT_MAX_TRIPLES,
		max_statement_bytes = DEFAULT_MAX_STATEMENT_BYTES,
		max_results = DEFAULT_MAX_RESULTS,
		max_query_bytes = DEFAULT_MAX_QUERY_BYTES,
		format = .Auto,
	}
	if len(args) == 0 do return options, Command_Error{code = .Missing_Command}
	if args[0] == "--help" || args[0] == "-h" {
		options.help = true
		return options, {}
	}
	switch args[0] {
	case "validate": options.command = .Validate
	case "query":    options.command = .Query
	case: return options, Command_Error{code = .Unknown_Command, value = args[0]}
	}
	for index := 1; index < len(args); index += 1 {
		argument := args[index]
		if argument == "--help" || argument == "-h" {
			options.help = true
			continue
		}
		value: string
		has_value := false
		if argument == "--data" || argument == "--shapes" || argument == "--query" || argument == "--format" || argument == "--max-data-triples" || argument == "--max-shapes-triples" || argument == "--max-statement-bytes" || argument == "--max-results" || argument == "--max-query-bytes" {
			if index + 1 >= len(args) do return options, Command_Error{code = .Missing_Option_Value, value = argument}
			index += 1
			value, has_value = args[index], true
		}
		if argument == "--data" || strings.has_prefix(argument, "--data=") {
			if !has_value do value = argument[len("--data="):]
			if len(options.data_path) > 0 do return options, Command_Error{code = .Duplicate_Data}
			options.data_path = value
			continue
		}
		if argument == "--shapes" || strings.has_prefix(argument, "--shapes=") {
			if options.command != .Validate do return options, Command_Error{code = .Unknown_Option, value = argument}
			if !has_value do value = argument[len("--shapes="):]
			if len(options.shapes_path) > 0 do return options, Command_Error{code = .Duplicate_Shapes}
			options.shapes_path = value
			continue
		}
		if argument == "--query" || strings.has_prefix(argument, "--query=") {
			if options.command != .Query do return options, Command_Error{code = .Unknown_Option, value = argument}
			if !has_value do value = argument[len("--query="):]
			if len(options.query_path) > 0 do return options, Command_Error{code = .Duplicate_Query}
			options.query_path = value
			continue
		}
		if argument == "--format" || strings.has_prefix(argument, "--format=") {
			if options.command != .Query do return options, Command_Error{code = .Unknown_Option, value = argument}
			if !has_value do value = argument[len("--format="):]
			format, valid := parse_query_format(value)
			if !valid do return options, Command_Error{code = .Invalid_Format, value = value}
			options.format = format
			continue
		}
		if argument == "--max-data-triples" || strings.has_prefix(argument, "--max-data-triples=") {
			if !has_value do value = argument[len("--max-data-triples="):]
			parsed, valid := parse_positive_decimal(value)
			if !valid do return options, Command_Error{code = .Invalid_Limit, value = value}
			options.max_data_triples = parsed
			continue
		}
		if argument == "--max-shapes-triples" || strings.has_prefix(argument, "--max-shapes-triples=") {
			if options.command != .Validate do return options, Command_Error{code = .Unknown_Option, value = argument}
			if !has_value do value = argument[len("--max-shapes-triples="):]
			parsed, valid := parse_positive_decimal(value)
			if !valid do return options, Command_Error{code = .Invalid_Limit, value = value}
			options.max_shapes_triples = parsed
			continue
		}
		if argument == "--max-statement-bytes" || strings.has_prefix(argument, "--max-statement-bytes=") {
			if !has_value do value = argument[len("--max-statement-bytes="):]
			parsed, valid := parse_positive_decimal(value)
			if !valid do return options, Command_Error{code = .Invalid_Limit, value = value}
			options.max_statement_bytes = parsed
			continue
		}
		if argument == "--max-results" || strings.has_prefix(argument, "--max-results=") {
			if !has_value do value = argument[len("--max-results="):]
			parsed, valid := parse_positive_decimal(value)
			if !valid do return options, Command_Error{code = .Invalid_Limit, value = value}
			options.max_results = parsed
			continue
		}
		if argument == "--max-query-bytes" || strings.has_prefix(argument, "--max-query-bytes=") {
			if options.command != .Query do return options, Command_Error{code = .Unknown_Option, value = argument}
			if !has_value do value = argument[len("--max-query-bytes="):]
			parsed, valid := parse_positive_decimal(value)
			if !valid do return options, Command_Error{code = .Invalid_Limit, value = value}
			options.max_query_bytes = parsed
			continue
		}
		return options, Command_Error{code = .Unknown_Option, value = argument}
	}
	if options.help do return options, {}
	if len(options.data_path) == 0 do return options, Command_Error{code = .Missing_Data}
	if options.command == .Validate && len(options.shapes_path) == 0 do return options, Command_Error{code = .Missing_Shapes}
	if options.command == .Query && len(options.query_path) == 0 do return options, Command_Error{code = .Missing_Query}
	if options.data_path == "-" || options.shapes_path == "-" || options.query_path == "-" do return options, Command_Error{code = .Invalid_Path}
	return options, {}
}

load_turtle :: proc(path: string, max_triples, max_statement_bytes: int, target: ^Owned_Triples) -> Load_Error {
	result: Load_Error
	input, open_error := os.open(path)
	if open_error != nil {
		result.open_error = open_error
		return result
	}
	defer _ = os.close(input)
	init_owned(target, max_triples)
	parsed := turtle.parse_reader(os.to_reader(input), triple_sink, {parse = {max_triples = max_triples}, max_statement_bytes = max_statement_bytes}, target)
	if target.limit {
		result.limit = true
		return result
	}
	if target.error {
		result.parse_error = turtle.Parse_Error{code = .Out_Of_Memory}
		return result
	}
	if parsed.error.code != .None {
		result.parse_error, result.reader_error = parsed.error, parsed.reader_error
		return result
	}
	return result
}

write_json_string :: proc(builder: ^strings.Builder, value: string) -> bool {
	if !utf8.valid_string(value) do return false
	strings.write_byte(builder, '"')
	for character in value {
		switch character {
		case '"': strings.write_string(builder, "\\\"")
		case '\\': strings.write_string(builder, "\\\\")
		case '\b': strings.write_string(builder, "\\b")
		case '\f': strings.write_string(builder, "\\f")
		case '\n': strings.write_string(builder, "\\n")
		case '\r': strings.write_string(builder, "\\r")
		case '\t': strings.write_string(builder, "\\t")
		case:
			if character < 0x20 {
				hex := "0123456789abcdef"
				strings.write_string(builder, "\\u00")
				strings.write_byte(builder, hex[u8(character >> 4)])
				strings.write_byte(builder, hex[u8(character & 0x0f)])
			} else {
				strings.write_rune(builder, character)
			}
		}
	}
	strings.write_byte(builder, '"')
	return true
}

write_json_term :: proc(builder: ^strings.Builder, term: rdf.Term) -> bool {
	strings.write_string(builder, "{\"type\":")
	switch term.kind {
	case .IRI:        if !write_json_string(builder, "iri") do return false
	case .Blank_Node: if !write_json_string(builder, "blankNode") do return false
	case .Literal:    if !write_json_string(builder, "literal") do return false
	case: return false
	}
	strings.write_string(builder, ",\"value\":")
	if !write_json_string(builder, term.value) do return false
	if term.kind == .Literal && len(term.language) > 0 {
		strings.write_string(builder, ",\"language\":")
		if !write_json_string(builder, term.language) do return false
	} else if term.kind == .Literal && term.datatype != rdf.XSD_STRING {
		strings.write_string(builder, ",\"datatype\":")
		if !write_json_string(builder, term.datatype) do return false
	}
	strings.write_byte(builder, '}')
	return true
}

component_name :: proc(component: validator.Constraint_Component) -> string {
	switch component {
	case .Min_Count: return "minCount"
	case .Max_Count: return "maxCount"
	case .Datatype:  return "datatype"
	case .Node_Kind: return "nodeKind"
	}
	return "unknown"
}

write_report_json :: proc(builder: ^strings.Builder, report: ^validator.Report) -> bool {
	strings.write_string(builder, "{\"conforms\":")
	strings.write_string(builder, report.conforms ? "true" : "false")
	strings.write_string(builder, ",\"results\":[")
	for result, index in report.results {
		if index > 0 do strings.write_byte(builder, ',')
		strings.write_string(builder, "{\"focusNode\":")
		if !write_json_term(builder, result.focus_node) do return false
		strings.write_string(builder, ",\"resultPath\":")
		if !write_json_term(builder, result.result_path) do return false
		if result.has_value {
			strings.write_string(builder, ",\"value\":")
			if !write_json_term(builder, result.value) do return false
		}
		strings.write_string(builder, ",\"sourceShape\":")
		if !write_json_term(builder, result.source_shape) do return false
		strings.write_string(builder, ",\"sourceConstraintComponent\":")
		if !write_json_string(builder, component_name(result.source_constraint_component)) do return false
		strings.write_string(builder, ",\"severity\":\"violation\"}")
	}
	strings.write_string(builder, "]}\n")
	return true
}

run_validate :: proc(options: Options, builder: ^strings.Builder) -> (exit_code: int, detail: string) {
	data, shapes: Owned_Triples
	data_error := load_turtle(options.data_path, options.max_data_triples, options.max_statement_bytes, &data)
	if data_error.open_error != nil do return Exit_Error, "cannot open data file"
	if data_error.limit { destroy_owned(&data); return Exit_Error, "data triple limit reached" }
	if data_error.parse_error.code != .None { destroy_owned(&data); return Exit_Error, turtle.parse_error_message(data_error.parse_error.code) }
	defer destroy_owned(&data)

	shapes_error := load_turtle(options.shapes_path, options.max_shapes_triples, options.max_statement_bytes, &shapes)
	if shapes_error.open_error != nil do return Exit_Error, "cannot open shapes file"
	if shapes_error.limit { destroy_owned(&shapes); return Exit_Error, "shapes triple limit reached" }
	if shapes_error.parse_error.code != .None { destroy_owned(&shapes); return Exit_Error, turtle.parse_error_message(shapes_error.parse_error.code) }
	defer destroy_owned(&shapes)

	report: validator.Report
	defer validator.destroy(&report)
	validation_error := validator.validate(data.triples[:], shapes.triples[:], &report, {
		max_data_triples = options.max_data_triples,
		max_shape_triples = options.max_shapes_triples,
		max_results = options.max_results,
	})
	if validation_error != .None do return Exit_Error, validator.error_message(validation_error)
	// Report owns terms. Release every parser-derived triple before rendering it.
	destroy_owned(&data)
	destroy_owned(&shapes)
	if !write_report_json(builder, &report) do return Exit_Error, "report contains invalid UTF-8"
	return report.conforms ? Exit_Conforms : Exit_Violations, ""
}

print_help :: proc() {
	fmt.println(`Usage:
  odin validate --data DATA.ttl --shapes SHAPES.ttl [--max-data-triples N] [--max-shapes-triples N] [--max-statement-bytes N] [--max-results N]
  odin query --data DATA.ttl --query QUERY.rq [--format auto|json|xml|csv|tsv|nt|turtle] [--max-data-triples N] [--max-statement-bytes N] [--max-query-bytes N] [--max-results N]

Validate two local Turtle files using the released bounded SHACL Core profile.
Standard output is one deterministic JSON report. Exit status is 0 when the
data conforms, 1 when it has validation results, and 2 for command, file,
Turtle, limit, shape-profile, or report errors. The command never opens a
network connection, performs inference, or retains a graph after reporting.

Query one local Turtle graph with one local SPARQL query document. The default
format is SPARQL Results JSON for SELECT and ASK, and N-Triples for graph
results. Exit status is 0 for a completed query, including an empty result, and
2 for command, file, Turtle, query, limit, execution, or serialization errors.
It never opens a network connection, executes a remote SERVICE, performs
inference, or creates persistent storage.`)
}

main :: proc() {
	options, command_error := parse_args(os.args[1:])
	if options.help {
		print_help()
		return
	}
	if command_error.code != .None {
		if len(command_error.value) > 0 {
			fmt.eprintfln("odin: %s: %s", error_message(command_error.code), command_error.value)
		} else {
			fmt.eprintfln("odin: %s", error_message(command_error.code))
		}
		os.exit(Exit_Error)
	}
	builder := strings.builder_make()
	exit_code: int
	detail: string
	switch options.command {
	case .Validate: exit_code, detail = run_validate(options, &builder)
	case .Query:    exit_code, detail = run_query(options, &builder)
	}
	if exit_code == Exit_Error {
		command_name := options.command == .Validate ? "validate" : "query"
		fmt.eprintfln("odin %s: %s", command_name, detail)
		os.exit(exit_code)
	}
	if _, write_error := io.write_string(os.to_writer(os.stdout), strings.to_string(builder)); write_error != .None {
		fmt.eprintfln("odin validate: cannot write report")
		os.exit(Exit_Error)
	}
	os.exit(exit_code)
}

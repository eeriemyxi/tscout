package tscout

import ts "./odin-tree-sitter"
import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:os/os2"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:sys/posix"

Language_Config :: struct {
	grammar_dll:  cstring,
	grammar_init: cstring,
	filters:      [dynamic]string,
}

State :: struct {
	parsers: map[string]ts.Parser,
}

traverse_identifiers :: proc(
	idendifiers: ^[dynamic]ts.Node,
	code: string,
	root_node: ts.Node,
	parent_filters: []string,
) {
	queue: [dynamic]ts.Node
	defer delete(queue)

	append(&queue, root_node)

	for len(queue) != 0 {
		cur := pop_front(&queue)
		type := ts.node_type(cur)
		if type == "identifier" {
			parent := ts.node_parent(cur)
			parent_type := ts.node_type(parent)
			log.debugf(
				"Found identifier: %v (%v) with parent type '%v'",
				ts.node_string(cur),
				ts.node_text(cur, code),
				parent_type,
			)
			if slice.contains(parent_filters, string(parent_type)) {
				append(idendifiers, cur)
			}
		}
		for i in 0 ..< ts.node_child_count(cur) {
			child := ts.node_child(cur, i)
			append(&queue, child)
		}
	}
}

join_exec_dir :: proc(path: string, allocator := context.allocator) -> (res: string, ok: bool) {
	context.allocator = allocator
	path := path
	if !filepath.is_abs(path) {
		dir, err := os2.get_executable_directory(context.temp_allocator)
		if err != nil do return "", false
		path = filepath.join({dir, path})
	}
	return path, true
}

load_config :: proc(
	config_map: ^map[string]Language_Config,
	config_path: string,
	allocator := context.allocator,
) -> (
	ok: bool,
	err_msg: string,
) {
	context.allocator = allocator

	config_path, jeok := config_path, true
	config_path, jeok = join_exec_dir(config_path)
	if !jeok {
		return false, fmt.tprintf(
			"config path=%v is relative but couldn't fetch executable directory. Use absolute path.",
			config_path,
		)
	}

	file, ferr := os2.read_entire_file(config_path, allocator)
	if ferr != nil {
		return false, fmt.tprintf("couldn't read file: %v (err: %v)", config_path, ferr)
	}

	value, jerr := json.parse(file, allocator = allocator)
	if jerr != nil {
		return false, fmt.tprintf("couldn't parse JSON: %v (err: %v)", config_path, jerr)
	}

	#partial switch config in value {
	case json.Object:
		for key in config {
			_, entry, is_new, err := map_entry(config_map, strings.clone(key))
			if err != nil {
				log.warnf(
					"Something went wrong when adding entry for key='%v' with err=%v. Skipping.",
					key,
					err,
				)
				continue
			}
			#partial switch c in config[key] {
			case json.Object:
				entry.grammar_dll = strings.clone_to_cstring(c["grammar_dll"].(json.String))
				entry.grammar_init = strings.clone_to_cstring(c["grammar_init"].(json.String))
				for fil in c["filters"].(json.Array) {
					append(&entry.filters, strings.clone(fil.(json.String)))
				}
			case:
				return false, fmt.tprintf(
					"invalid configuration for extension '%v' for configuration file '%v'",
					key,
					config_path,
				)
			}
		}
		log.debugf("Parsed configuration: %v", config_map)
		return true, ""
	case:
		return false, fmt.tprintf("invalid configuration file: %v", config_path)
	}
}

handle_file :: proc(
	state: ^State,
	config: map[string]Language_Config,
	path: string,
	full_text: bool = false,
) {
	ext := filepath.ext(path)
	file_conf, ok := config[ext]
	if !ok {
		log.debugf("Configuration not found for %v, skipping...", path)
		return
	}
	log.debugf("Loaded configuration for %v: %v", path, file_conf)

	file, ferr := os2.read_entire_file(path, context.temp_allocator)
	if ferr != nil {
		log.errorf("File not found: %v", path)
		return
	}
	code := string(file)

	parser, gpok, gpemsg := get_parser(state, ext, file_conf)
	if !gpok {
		log.errorf("Error while handling file '%v': %v", path, gpemsg)
		return
	}
	tree := ts.parser_parse_string(parser, code)
	defer ts.tree_delete(tree)

	root_node := ts.tree_root_node(tree)
	log.debugf("S-expression tree: %v", ts.node_string(root_node))

	identifiers: [dynamic]ts.Node
	defer delete(identifiers)

	traverse_identifiers(&identifiers, code, root_node, file_conf.filters[:])

	for ident in identifiers {
		loc := ts.node_start_point(ident)
		parent := ts.node_parent(ident)
		text := ts.node_text(parent, code)
		fmt.printfln(
			"%s:%v:%v:%s",
			path,
			loc.row + 1,
			loc.col + 1,
			full_text ? text : strings.truncate_to_rune(text, '\n'),
		)
	}

	free_all(context.temp_allocator)
}

get_grammar :: proc(path: cstring, symbol_name: cstring) -> proc() -> ts.Language {
	handle := posix.dlopen(path, posix.RTLD_LOCAL + {.LAZY})
	return auto_cast posix.dlsym(handle, symbol_name)
}

get_parser :: proc(
	state: ^State,
	ext: string,
	file_conf: Language_Config,
) -> (
	parser: ts.Parser,
	ok: bool,
	err_msg: string,
) {
	if parser, ok := state.parsers[ext]; ok {
		log.debugf("Parser for ext='%v' was found in state: %v", ext, state.parsers)
		return parser, true, ""
	}
	log.debugf("Parser for ext='%v' was NOT found in state: %v", ext, state.parsers)
	parser = ts.parser_new()
	dll_path, jeok := join_exec_dir(string(file_conf.grammar_dll), context.temp_allocator)
	dll_path_cstr := strings.unsafe_string_to_cstring(dll_path)
	if !jeok {
		return parser, false, fmt.tprintf(
			"DLL path not found, try absolute path (ext='%v'): %v",
			ext,
			dll_path_cstr,
		)
	}
	grammar_init := get_grammar(dll_path_cstr, file_conf.grammar_init)
	grammar := grammar_init()
	ts.parser_set_language(parser, grammar)
	state.parsers[ext] = parser
	return parser, true, ""
}

display_version :: proc() {
	fmt.printfln(
		"tscout version %v (%v %v)",
		#config(VERSION, "none"),
		#config(GIT_HASH, "none")[1:], // Sometimes, it gets interpreted as integer otherwise
		#config(COMP_DATE, "none"),
	)
}

Options :: struct {
	i: string `args:"pos=0" usage:"Input file or directory"`,
	v: bool `usage:"Show version info"`,
	d: int `usage:"Directory traversal depth. 1 by default. -1 for infinite"`,
	f: bool `usage:"Include full text for each match"`,
	c: string `usage:"Override config path"`,
	l: log.Level `usage:"Set log level. Info by default. Options: Debug, Info, Warning, Error, Fatal"`,
}

opt: Options

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	opt.l = .Info
	opt.d = 1
	opt.f = false
	opt.c = "config.json"

	style: flags.Parsing_Style = .Odin
	flags.parse_or_exit(&opt, os.args, style)

	context.logger = log.create_console_logger(opt.l)
	defer log.destroy_console_logger(context.logger)

	if opt.v {
		display_version()
		os2.exit(0)
	}

	if len(opt.i) == 0 {
		log.error("Input file or directory wasn't provided. Check -help or -h")
		os2.exit(1)
	}

	config: map[string]Language_Config
	config_arena: vmem.Arena
	ensure(vmem.arena_init_growing(&config_arena) == nil)
	config_arena_alloc := vmem.arena_allocator(&config_arena)
	defer vmem.arena_destroy(&config_arena)

	ok, err_msg := load_config(&config, opt.c, config_arena_alloc)
	if !ok {
		log.errorf("Loading configuration file failed: %s", err_msg)
		os2.exit(1)
	}

	state := State{}
	defer {
		for key in state.parsers {
			ts.parser_delete(state.parsers[key])
		}
		delete(state.parsers)
	}

	queue: [dynamic]os2.File_Info
	defer delete(queue)

	depth := 0

	cur_file, err := os2.stat(opt.i, config_arena_alloc)
	if err != nil {
		log.errorf("Couldn't get stats for file: %v (err: %v)", opt.i, err)
		os2.exit(1)
	}
	append(&queue, cur_file)

	for len(queue) != 0 {
		if depth > opt.d && opt.d != -1 do break
		for i := 0; i < len(queue); i += 1 {
			cur_file = pop_front(&queue)
			file_path := cur_file.fullpath
			if os2.is_dir(file_path) {
				files, err := os2.read_all_directory_by_path(file_path, config_arena_alloc)
				if err != nil {
					log.errorf("Encountered error while reading directory: %v", opt.i)
					os2.exit(1)
				}
				for file in files do append(&queue, file)
			} else if os2.is_file(file_path) {
				log.debugf("Processing file: %v", file_path)
				handle_file(&state, config, file_path, opt.f)
				log.debugf("Finished processing file: %v", file_path)
			} else {
				log.debugf("Skipping (not a file or directory): %v", file_path)
				continue
			}
		}
		depth += 1
	}

	free_all(context.temp_allocator)
}

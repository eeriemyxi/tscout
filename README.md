# Tscout
Tscout utilizes tree-sitter language grammar dynamic libraries to scout for
useful (configurable) identifiers from source files and emits them on standard output.

The dynamic libraries are loaded at runtime via `dlopen` and `dlsym` so that
adding support for new parsers is as trivial as editing a JSON configuration file.

> [!IMPORTANT] 
> Only POSIX-based systems are supported at the moment. This is
> because `dlopen` and `dlsym` are only defined by the POSIX standard. Windows
> support is planned in upcoming releases.

# Demo
https://github.com/user-attachments/assets/77330090-8522-4377-96fe-cebf1b7a6ec5

# Example Configuration
```json
{
  ".odin": {
    "grammar_dll": "../libtree-sitter-odin.so",
    "grammar_init": "tree_sitter_odin",
    "filters": ["procedure_declaration", "struct_declaration", "var_declaration", "const_declaration", "enum_declaration"]
  },
  ".c": {
    "grammar_dll": "../libtree-sitter-c.so",
    "grammar_init": "tree_sitter_c",
    "filters": ["function_declarator", "struct_specifier", "declaration", "type_definition", "enum_specifier", "preproc_def", "preproc_function_def"]
  },
  ".h": {
    "grammar_dll": "../libtree-sitter-c.so",
    "grammar_init": "tree_sitter_c",
    "filters": ["function_declarator", "struct_specifier", "declaration", "type_definition", "enum_specifier", "preproc_def", "preproc_function_def"]
  }
}
```

The JSON file is mostly self-explanatory, so I'll spare you the descriptions for now.

> [!IMPORTANT]
> The current working directory is _not_ used. This may be implemented as an optional flag in the future.

By default it looks for the configuration file `config.json` at the directory where the `tscout` executable resides. Use `-c` flag to override it.

Relative paths are joined with the directory where the `tscout` executable
resides. Use absolute paths to avoid that if necessary.

# Command-line Arguments
Help: `tscout -help`

```
Usage:
        tscout [i] [-c] [-d] [-f] [-l] [-v]
Flags:
        -i:<string>        | Input file or directory
                           |
        -c:<string>        | Override config path
        -d:<int>           | Directory traversal depth. 1 by default. -1 for infinite
        -f                 | Include full text for each match
        -l:<Logger_Level>  | Set log level. Info by default. Options: Debug, Info, Warning, Error, Fatal
        -v                 | Show version info
```

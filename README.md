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
### Emacs
https://github.com/user-attachments/assets/c141e345-9731-45a6-815a-8fe0fdb0a3b2
#### Configuration
This was largely LLM-generated because I don't know Elisp and neither want to.
```lisp
(defun my/tscout--jump (cand)
  (when (string-match
         "^\\([^:]+\\):\\([0-9]+\\):\\([0-9]+\\):"
         cand)
    (let ((file (match-string 1 cand))
          (line (string-to-number (match-string 2 cand)))
          (col  (string-to-number (match-string 3 cand))))
      (find-file file)
      (goto-char (point-min))
      (forward-line (1- line))
      (move-to-column (- col 1)))))

(defun my/tscout (&optional dir)
  (interactive)
  (let* ((default-directory
          (or dir
              ;; Projectile (preferred)
              (when (fboundp 'projectile-project-root)
                (ignore-errors (projectile-project-root)))
              ;; project.el fallback
              (and (fboundp 'project-current)
                   (when-let ((proj (project-current)))
                     (project-root proj)))
              default-directory))
         (candidates
          (process-lines "tscout" "." "-d:-1")))
    (unless candidates
      (user-error "No tscout results found"))
    (my/tscout--jump
     (if (fboundp 'consult--read)
         (consult--read
          candidates
          :prompt "tscout: ")
       (completing-read
        "tscout: "
        candidates
        nil
        t)))))
```

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

# Installation
Tscout has officially only been tested on a Linux AMD64 system.

### Prebuilt Binaries
You can download prebuilt binaries from [Github Releases](https://github.com/eeriemyxi/tscout/releases/latest). Platforms included:
- Linux AMD64

### Compile from Source
Tscout was developed using the [Odin](https://odin-lang.org) programming language.

```bash
git clone --recurse-submodules https://github.com/eeriemyxi/tscout
cd tscout
make
bin/tscout -help
```

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

ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
else
    DETECTED_OS := $(shell uname)
endif

DEBUG = 0
OPTIMIZATION = aggressive
BIN = bin
PROGRAM_NAME = tscout
PROGRAM_EXT = .bin
PLATFORM = linux_amd64
TARGET = $(BIN)/$(PROGRAM_NAME)$(PROGRAM_EXT)
TREE_SITTER_LIB := odin-tree-sitter/tree-sitter/libtree-sitter.a

COMP_DATE = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_HASH = $(shell git rev-parse --short HEAD)
VERSION = $(shell git describe --tags --dirty --always)

EXTRA_FLAGS = #-strict-style -vet-tabs -warnings-as-errors
ifeq ($(DEBUG),1)
	EXTRA_FLAGS += -debug
endif

DEFINES = -define:VERSION=$(VERSION) -define:GIT_HASH=x$(GIT_HASH) -define:COMP_DATE=$(COMP_DATE) -define:PROGRAM_NAME=$(PROGRAM_NAME)

ifeq ($(DETECTED_OS),Windows)
	PROGRAM_EXT = .exe
	TARGET = $(BIN)\$(PROGRAM_NAME)$(PROGRAM_EXT)
	TREE_SITTER_LIB := odin-tree-sitter/tree-sitter/libtree-sitter.lib
	PLATFORM := windows_amd64
	COMP_DATE = $(shell powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')")
endif

.PHONY: all clean

all: $(TARGET)

$(BIN):
ifeq ($(DETECTED_OS),Windows)
	mkdir $(BIN)
else
	mkdir -p $(BIN)
endif

$(TARGET): *.odin $(TREE_SITTER_LIB) | $(BIN)
	odin build . -out:$(TARGET) -o:$(OPTIMIZATION) -target:$(PLATFORM) $(DEFINES) $(EXTRA_FLAGS)

$(TREE_SITTER_LIB):
	odin run odin-tree-sitter/build -- install

ifeq ($(DETECTED_OS),Windows)
clean: SHELL := cmd.exe
clean: .SHELLFLAGS := /C
clean:
	if exist "$(TARGET)" del "$(TARGET)"
	if exist "$(BIN)" rmdir /S /Q "$(BIN)"
	if exist "odin-tree-sitter\tree-sitter" rmdir /S /Q "odin-tree-sitter\tree-sitter"
else
clean:
	rm -f $(TARGET)
	rmdir $(BIN) 2>/dev/null || true
	rm -rf odin-tree-sitter/tree-sitter
endif

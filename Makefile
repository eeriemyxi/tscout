ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
else
    DETECTED_OS := $(shell uname)
endif

OPTIMIZATION = aggressive
PROGRAM_NAME = tscout
TARGET = $(BIN)/$(PROGRAM_NAME)
TREE_SITTER_LIB := odin-tree-sitter/tree-sitter/libtree-sitter.a
PLATFORM := linux_amd64
BIN = bin
DEBUG=0

COMP_DATE = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_HASH = $(shell git rev-parse --short HEAD)
VERSION = $(shell git describe --tags --dirty --always)

EXTRA_FLAGS = #-strict-style -vet-tabs -warnings-as-errors
ifeq ($(DEBUG),1)
	EXTRA_FLAGS += -debug
endif

DEFINES = -define:VERSION=$(VERSION) -define:GIT_HASH=x$(GIT_HASH) -define:COMP_DATE=$(COMP_DATE) -define:PROGRAM_NAME=$(PROGRAM_NAME)

ifeq ($(DETECTED_OS),Windows)
	TARGET = $(BIN)\$(PROGRAM_NAME)
	TREE_SITTER_LIB := odin-tree-sitter/tree-sitter/libtree-sitter.lib
	PLATFORM := windows_amd64
	PROGRAM_NAME = tscout.exe
	COMP_DATE = $(shell powershell -NoProfile -Command "(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')")
endif

.PHONY: all clean

all: $(TARGET)

$(BIN):
ifeq ($(DETECTED_OS),Linux)
	mkdir -p $(BIN)
else
	mkdir $(BIN)
endif

$(TARGET): *.odin $(TREE_SITTER_LIB) | $(BIN)
	odin build . -out:$(TARGET) -o:$(OPTIMIZATION) -target:$(PLATFORM) $(DEFINES) $(EXTRA_FLAGS)

$(TREE_SITTER_LIB):
	odin run odin-tree-sitter/build -- install

ifeq ($(DETECTED_OS),Linux)
clean:
	rm -f $(TARGET)
	rmdir $(BIN) 2>/dev/null || true
	rm -rf odin-tree-sitter/tree-sitter
else
clean: SHELL := cmd.exe
clean: .SHELLFLAGS := /C
clean:
	if exist "$(TARGET)" del "$(TARGET)"
	if exist "$(BIN)" rmdir /S /Q "$(BIN)"
	if exist "odin-tree-sitter\tree-sitter" rmdir /S /Q "odin-tree-sitter\tree-sitter"
endif

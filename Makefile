OPTIMIZATION = aggressive
PROGRAM_NAME = tscout
BIN = bin
PLATFORM = linux_amd64
DEBUG=0
TARGET = $(BIN)/$(PROGRAM_NAME)
COMP_DATE = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_HASH = $(shell git rev-parse --short HEAD)
VERSION = $(shell git describe --tags --dirty --always)
# Disabled: -vet
EXTRA_FLAGS = #-strict-style -vet-tabs -warnings-as-errors
ifeq ($(DEBUG),1)
	EXTRA_FLAGS += -debug
endif
DEFINES = -define:VERSION=$(VERSION) -define:GIT_HASH=x$(GIT_HASH) -define:COMP_DATE=$(COMP_DATE) -define:PROGRAM_NAME=$(PROGRAM_NAME)

.PHONY: all clean

all: $(TARGET)

$(BIN):
	mkdir -p $(BIN)

$(TARGET): *.odin | $(BIN)
	odin build . -out:$(TARGET) -o:$(OPTIMIZATION) -target:$(PLATFORM) $(DEFINES) $(EXTRA_FLAGS)

clean:
	rm -f $(TARGET)
	rmdir $(BIN) 2>/dev/null || true

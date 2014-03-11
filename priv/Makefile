PROJECT = {{{PROJECT_NAME}}}

## elixir

ELIXIR_URL ?= https://github.com/elixir-lang/elixir.git
ELIXIR_BRANCH ?= stable
MIX_ENV ?= prod

ELIXIR_BUILD_DIR := _elixir
ELIXIR_ABS_BUILD_DIR := $(shell pwd)/$(ELIXIR_BUILD_DIR)
ELIXIR := $(ELIXIR_BUILD_DIR)/VERSION
MIX := $(ELIXIR_BUILD_DIR)/bin/mix

mix = MIX_ENV=$(MIX_ENV) $(MIX)

## rebar

REBAR_URL ?= https://github.com/rebar/rebar.git
REBAR_TAG ?= 2.2.0

REBAR := $(shell pwd)/rebar
REBAR_BUILD_DIR := .rebar-build
REBAR_ABS_BUILD_DIR := $(shell pwd)/$(REBAR_BUILD_DIR)

rebar_args_3 = -v 3
rebar_args_2 = -v 2
rebar_args_1 = -v 1
rebar_args = $(rebar_args_$(V))

rebar_verbose_0 = @echo ":: REBAR" $(@F);
rebar_verbose = $(rebar_verbose_$(V))

rebar = $(rebar_verbose) V=$(V) TEST=$(TEST) $(REBAR) $(rebar_args)

## relx

RELX_URL ?= https://github.com/erlware/relx/releases/download/v0.6.0/relx

RELX := $(shell pwd)/relx
RELX_BUILD_DIR := $(shell pwd)/.relx-build

relx_args_3 = -V 3
relx_args_2 = -V 2
relx_args_1 = -V 1
relx_args = $(relx_args_$(V))

relx_verbose_0 = @echo ":: RELX" $(@F);
relx_verbose = $(relx_verbose_$(V))

relx = $(relx_verbose) V=$(V) TEST=$(TEST) $(RELX) $(relx_args)

.PHONY: deps update-deps deps-compile compile build generate rel clean distclean

all: build

deps: get-deps deps-compile

get-deps: $(ELIXIR)
	$(mix) deps.get

update-deps: $(ELIXIR)
	$(mix) deps.update --all

deps-compile: $(ELIXIR)
	$(mix) deps.compile

clean-deps:
	rm -rf deps

compile: $(ELIXIR)
	$(mix) compile

build: $(ELIXIR) deps
	$(mix) compile

clean-build:
	rm -rf $(shell pwd)/_build

rel: $(RELX) all
	$(relx) --config rel/relx.config --relname $(PROJECT) --relvsn "$(shell git describe --always --tags | sed -e s/^v//)" --output-dir rel/$(PROJECT)	

clean-rel:
	rm -rf rel/$(PROJECT)

clean: clean-rel clean-build

clean-all: clean clean-deps clean-elixir clean-rebar clean-relx

##
## Developer targets
##
##  stage - Make a production rel for use in development
.PHONY: stage-generate stage

stage-generate: relx_args+=--dev-mode
stage-generate: generate

stage: all stage-generate

##
## elixir
##
.PHONY: elixir

elixir: $(ELIXIR)

$(ELIXIR): $(REBAR)
	git clone $(ELIXIR_URL) $(ELIXIR_BUILD_DIR)
	cd $(ELIXIR_ABS_BUILD_DIR) && git checkout $(ELIXIR_BRANCH)
	$(MAKE) -C $(ELIXIR_ABS_BUILD_DIR)

clean-elixir:
	rm -rf $(ELIXIR_ABS_BUILD_DIR)

##
## rebar
##
.PHONY: rebar

rebar: $(REBAR)

$(REBAR):
	git clone $(REBAR_URL) $(REBAR_BUILD_DIR)
	cd $(REBAR_ABS_BUILD_DIR) && git checkout $(REBAR_TAG)
	$(MAKE) -C $(REBAR_ABS_BUILD_DIR)
	mv $(REBAR_ABS_BUILD_DIR)/rebar $(shell pwd)/rebar
	rm -rf $(REBAR_ABS_BUILD_DIR)

clean-rebar:
	rm -f $(REBAR)
	rm -rf $(REBAR_ABS_BUILD_DIR)

##
## relx
##
.PHONY: relx

relx: $(RELX)

$(RELX):
	wget -O $(RELX) $(RELX_URL) || rm $(RELX)
	chmod +x $(RELX)

clean-relx:
	rm -f relx

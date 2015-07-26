# -*- mode: Makefile -*-

MKDIR    := mkdir -p
RM       := rm -rf
CP       := cp -rf
REBAR    := rebar
ERL      := erl
ESCRIPT   := escript


QUIET    := @


build_support_dir      := $(CURDIR)/build-support
deps_dir               := $(CURDIR)/deps
src_dir                := $(CURDIR)/src
ast_dir                := $(src_dir)/ast
test_dir               := $(CURDIR)/test
bootstrap_output_dir   := $(CURDIR)/.bootstrap
test_output_dir        := $(CURDIR)/.eunit
beam_output_dir        := $(CURDIR)/ebin


compiler_modules :=      \
  joxa-cmp-util          \
  joxa-cmp-path          \
  joxa-cmp-ctx           \
  joxa-cmp-peg           \
  joxa-cmp-lexer         \
  joxa-cmp-ns            \
  joxa-cmp-call          \
  joxa-cmp-literal       \
  joxa-cmp-binary        \
  joxa-cmp-special-forms \
  joxa-cmp-case          \
  joxa-cmp-spec          \
  joxa-cmp-expr          \
  joxa-cmp-defs          \
  joxa-cmp-joxa-info     \
  joxa-cmp-checks        \
  joxa-cmp-error-format  \
  joxa-cmp-parser        \
  joxa-compiler
compiler_jxa_files            := $(addprefix $(src_dir)/,$(addsuffix .jxa,$(compiler_modules)))
compiler_ast_files            := $(addprefix $(ast_dir)/,$(addsuffix .ast,$(compiler_modules)))
compiler_bootstrap_beam_files := $(addprefix $(bootstrap_output_dir)/,$(addsuffix .beam,$(compiler_modules)))
compiler_beam_files           := $(addprefix $(beam_output_dir)/,$(addsuffix .beam,$(compiler_modules)))

lib_modules :=             \
  joxa-core                 \
  joxa-shell                \
  joxa-records              \
  joxa-assert               \
  joxa-eunit                \
  joxa-lists                \
  joxa-otp                  \
  joxa-otp-gen-server       \
  joxa-sort-topo            \
  joxa-concurrent-compiler  \
  joxa-cc-wkr               \
  joxa                      \
  joxa-build-support        \
  joxa-otp-application      \
  joxa-otp-supervisor
lib_jxa_files      := $(addprefix $(src_dir)/,$(addsuffix .jxa,$(lib_modules)))
lib_ast_files      := $(addprefix $(ast_dir)/,$(addsuffix .ast,$(lib_modules)))
lib_beam_files     := $(addprefix $(beam_output_dir)/,$(addsuffix .beam,$(lib_modules)))

test_modules :=                              \
  joxa-test-let-match                        \
  joxa-test-multiple-namespaces              \
  joxa-test-namespace-mutual-recursion       \
  joxa-test-lexical-scoping                  \
  joxa-test-joxification                     \
  joxa-test-core-and                         \
  joxa-test-core-or                          \
  joxa-test-core-add                         \
  joxa-test-core-subtract                    \
  joxa-test-cc

test_beam_files   := $(addprefix $(test_output_dir)/,$(addsuffix .beam,$(test_modules)))

beam_files              := $(compiler_beam_files) $(lib_beam_files)
joxa_compiler_beam_file := $(beam_output_dir)/joxa-compiler.beam
build_support_beam_file := $(beam_output_dir)/joxa-build-support.beam
bootstrap_beam_file     := $(beam_output_dir)/jxa_bootstrap.beam
app_src_file            := $(src_dir)/joxa.app.src
shell_src_file          := $(src_dir)/joxa-shell.jxa
version                 := $(shell $(build_support_dir)/semver.sh)
escript_file            := $(CURDIR)/joxa
crash_dump_file         := $(CURDIR)/erl_crash.dump


# ensure directory's existence
# $(call ensure-dir,dir-name)
define ensure-dir
  $(QUIET) [ -d "$1" ] || $(MKDIR) $1
endef

# check the existence of command
# $(call check-cmd,cmd-name)
define check-cmd
  $(QUIET) if ! which "$1" > /dev/null; then echo "command" "$1" "not found"; exit 1; fi
endef

# generate erl code path options
# $(call get-code-path-options,pattern)
define get-code-path-options
  $(foreach path,$(wildcard $1),-pz $(path))
endef

ERL_OPTIONS      := -noshell -pa $(CURDIR)/ebin $(call get-code-path-options,$(deps_dir)/*/ebin)
ERL_TEST_OPTIONS := $(call get-code-path-options,$(test_output_dir))

# call erl command line
# $(call erl,file,function,arguments...)
define erl
  $(QUIET) $(ERL) $(ERL_OPTIONS) -s $1 $2 $3 -s init stop
endef

ERLC_OPTIONS      := $(ERL_OPTIONS)
ERLC_TEST_OPTIONS := $(ERL_TEST_OPTIONS)

# call erlc command line
# $(call erlc,file,outdir)
define erlc
  $(QUIET) $(ERLC) $(ERLC_OPTIONS) $(ERLC_TEST_OPTIONS) -o "$2" "$1"
endef

# do one of these bootstrap functions:
# compile ast to beam, compile jxa to beam, compile jxa to ast
# $(call bootstrap,function,arguments)
define bootstrap-run
  $(QUIET) $(ESCRIPT) $(build_support_dir)/bootstrap.erl $1 $2
endef

# call joxa-build-support module main function with specified argument
# $(call joxa-build-support,argument)
define joxa-build-support
  $(QUIET) $(ERL) $(ERL_OPTIONS) $(ERL_TEST_OPTIONS) -s 'joxa-build-support' main $1 -s init stop
endef

# use joxa compiler to compile jxa source file
# $(call joxa-compile,file,outdir)
define joxa-compile
  $(QUIET) $(ERL) $(ERL_OPTIONS) $(ERL_TEST_OPTIONS) -s 'joxa-compiler' main -extra "$1" -o "$2"
endef

# open joxa interactive shell
# $(call joxa-shell)
define joxa-shell
  $(QUIET) $(ERL) $(ERL_OPTIONS) -s joxa main -s init stop
endef


.PHONY : all build \
  deps update-versions        \
  shell escript               \
  bootstrap bootstrap-message \
  compiler compiler-message   \
  lib lib-message             \
  ast ast-message             \
  test eunit proper cucumberl \
  clean deps-clean dist-clean


all: build

build: deps update-versions bootstrap lib

deps:
	$(call check-cmd,$(REBAR))
	$(QUIET) echo "--- downloading dependent packages ---" && $(REBAR) get-deps
	$(QUIET) echo "--- compiling dependent packages ---" && $(REBAR) compile

update-versions:
	$(QUIET) cat ${app_src_file} | perl -p -e "s/({vsn, \")[^\"]*(\"},)/\$${1}${version}\$${2}/g" > ${app_src_file}.tmp
	$(QUIET) mv ${app_src_file}.tmp ${app_src_file}
	$(QUIET) cat ${shell_src_file} | perl -p -e "s/(Joxa Version ).*?(~n~n)/\$${1}${version}\$${2}/g" > ${shell_src_file}.tmp
	$(QUIET) mv ${shell_src_file}.tmp ${shell_src_file}

bootstrap: bootstrap-message compiler ast
bootstrap-message:
	$(QUIET) echo "--- bootstraping ---"

compiler: deps compiler-message $(compiler_beam_files)
compiler-message:
	$(QUIET) echo "--- compiling compiler ---"

$(compiler_beam_files): $(beam_output_dir)/%.beam: $(bootstrap_output_dir)/%.beam
	$(call ensure-dir,$(dir $@))
	$(QUIET) $(CP) $< $@

$(compiler_bootstrap_beam_files): $(bootstrap_output_dir)/%.beam: $(ast_dir)/%.ast $(bootstrap_script_file)
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call bootstrap-run,compile_ast_to_beam,$< $(dir $@))

lib: lib-message $(lib_beam_files)
lib-message:
	$(QUIET) echo "--- compiling lib ---"

$(lib_beam_files): $(compiler_beam_files)
$(lib_beam_files): $(beam_output_dir)/%.beam: $(src_dir)/%.jxa $(bootstrap_script_file)
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call bootstrap-run,compile_jxa_to_beam,$< $(dir $@))

ast: compiler ast-message $(compiler_ast_files)
ast-message:
	$(QUIET) echo "--- compiling ast ---"

$(compiler_ast_files): $(ast_dir)/%.ast: $(src_dir)/%.jxa $(bootstrap_script_file)
	$(call ensure-dir, $(dir $@))
	$(QUIET) printf "compiling file '%s' to ast\n" $<
	$(call bootstrap-run,compile_jxa_to_ast,$< $(dir $@) $@)

shell: build $(test_beam_files)
	$(call joxa-shell)

$(test_output_dir)/%.beam: $(test_dir)/%.erl
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call erlc,$<,$(dir $@))

$(test_output_dir)/%.beam: $(test_dir)/%.jxa $(joxa_compiler_beam_file)
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call joxa-compile,$<,$(dir $@))

escript: $(escript_file)

$(escript_file): build
	$(call check-cmd,$(REBAR))
	$(QUIET) printf "creating escript '%s'\n" $<
	$(QUIET) $(REBAR) skip-deps=true escriptize

test: eunit proper cucumberl $(test_beam_files)

eunit: build $(build_support_beam_file)
	$(call check-cmd,$(REBAR))
	$(QUIET) $(REBAR) skip_deps=true eunit
	$(call joxa-build-support,eunit $(beam_output_dir))
	$(call joxa-build-support,eunit $(test_output_dir))

proper: eunit $(build_support_beam_file)
	$(call joxa-build-support,$@ $(test_output_dir))

cucumberl: eunit $(build_support_beam_file)
	$(call joxa-build-support,$@ $(CURDIR))

clean:
	$(call check-cmd,$(REBAR))
	$(REBAR) skip_deps=true clean
	$(RM) $(escript_file) $(crash_dump_file) $(bootstrap_output_dir) $(beam_output_dir) $(test_output_dir)

deps-clean:
	$(RM) $(deps_dir)

include $(abspath $(build_support_dir)/doc.mkf)

dist-clean: clean deps-clean doc-clean


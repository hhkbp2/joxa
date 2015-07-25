# -*- mode: Makefile -*-

MKDIR    := mkdir -p
REBAR    := rebar
ERL      := erl
ESCRIT   := escript


QUIET    := @


build_support_dir      := $(CURDIR)/build-support
deps_dir               := $(CURDIR)/deps
src_dir                := $(CURDIR)/src
ast_dir                := $(src_dir)/ast
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
compiler_jxa_files  := $(addprefix $(src_dir)/,$(addsuffix .jxa,$(compiler_modules)))
compiler_ast_files  := $(addprefix $(ast_dir)/,$(addsuffix .ast,$(compiler_modules)))
compiler_beam_files := $(addprefix $(beam_output_dir)/,$(addsuffix .beam,$(compiler_modules)))

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

app_src_file    := $(src_dir)/joxa.app.src
shell_src_file  := $(src_dir)/joxa-shell.jxa
version         := $(shell $(build_support_dir)/semver.sh)


# ensure directory's existence
# $(call ensure-dir,dir-name)
define ensure-dir
  $(QUIET) $(MKDIR) $1
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

ERL_OPTIONS   := -noshell -pa $(CURDIR)/ebin $(call get-code-path-options,$(deps_dir)/*/ebin)

# call erl command line
# $(call erl,file,function,arguments...)
define erl
  $(QUIET) $(ERL) $(ERL_OPTIONS) -s $1 $2 $3 -s init stop
endef

.PHONY : all build update-versions \
bootstrap bootstrap-message \
compiler compiler-message   \
lib lib-message             \
ast ast-message

all: build

build: update-versions
	$(call check-cmd,$(REBAR))
	$(REBAR) compile

# update-versions:
# 	$(QUIET) cat ${app_src_file} | sed -e 's;^\([^{]*{vsn, "\)[^"]*\("},.*\);\1${version}\2;g' > ${app_src_file}.tmp
# 	$(QUIET) mv ${app_src_file}.tmp ${app_src_file}
# 	$(QUIET) cat ${shell_src_file} | sed -e 's;^\([^"]*"Joxa Version \).*\(~n~n.*\);\1${version}\2;g' > ${shell_src_file}.tmp
# 	$(QUIET) mv ${shell_src_file}.tmp ${shell_src_file}

update-versions:
	$(QUIET) cat ${app_src_file} | perl -p -e "s/({vsn, \")[^\"]*(\"},)/\$${1}${version}\$${2}/g" > ${app_src_file}.tmp
	$(QUIET) mv ${app_src_file}.tmp ${app_src_file}
	$(QUIET) cat ${shell_src_file} | sed -e "s/(Joxa Version ).*?(~n~n)/\$${1}${version}\$${2}/g" > ${shell_src_file}.tmp
	$(QUIET) mv ${shell_src_file}.tmp ${shell_src_file}

bootstrap: bootstrap-message compiler ast
bootstrap-message:
	$(QUIET) echo "--- bootstraping ---"

compiler: compiler-message $(compiler_beam_files)
compiler-message:
	$(QUIET) echo "--- compiling compiler ---"

$(compiler_beam_files): $(compiler_)
$(beam_output_dir)/%.beam: $(ast_dir)/%.ast
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call erl,'jxa_bootstrap','do_bootstrap',$(dir $@) $<)

lib: lib-message $(lib_beam_files)
lib-message:
	$(QUIET) echo "--- compiling lib ---"

$(lib_beam_files): $(beam_output_dir)/%.beam: $(src_dir)/%.jxa
	$(call ensure-dir,$(dir $@))
	$(QUIET) printf "compiling file '%s' to beam\n" $<
	$(call erl,'jxa_bootstrap','do_compile_jxa',$(dir $@) $<)

ast: ast-message $(compiler_ast_files)
ast-message:
	$(QUIET) echo "--- compiling ast ---"

$(compiler_ast_files): $(ast_dir)/%.ast: $(src_dir)/%.jxa
	$(call ensure-dir, $(dir $@))
	$(QUIET) printf "compiling file '%s' to ast\n" $<
	$(call erl,'jxa_bootstrap','do_compile_ast',$(dir $@) $< $@)


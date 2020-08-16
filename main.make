#
# Copyright (C) 2014 Jan Nowotsch
# Author Jan Nowotsch	<jan.nowotsch@gmail.com>
#
# Released under the terms of the GNU GPL v2.0
#



include $(scripts_dir)/Makefile.helper

######################################
###   first stage 'make prepare'   ### 
######################################


# check if prestage <stage> is currently executed
#
#	$(call is_prestage,<stage>)
define is_prestage
$(findstring $(1),$(PRESTAGE))
endef

# execute <cmd> during all stages except during <stages>
#
#	$(call skip_prestage,<stages>,<cmd>)
define skip_prestage
    $(if $(findstring $(PRESTAGE),$(1)),@:,$(2))
endef

# call make with the prestage target <stage-target>, setting the following
# environment variables to indicate prestage execution
# 	EXEC_PRESTAGE
# 	PRESTAGE
#
#	$(call prestage,<stage-name>,<targets>)
define prestage
  $(call pdebug0,prestage $(1) $(2)) \
  \
  $(eval r := $(shell \
      EXEC_PRESTAGE=$(prestage_key) \
      PRESTAGE=$(1) \
      $(MAKE) $(MFLAGS) $(MAKEOVERRIDES) $(2) 1>&2; \
      echo $$?
    ) \
  ) \
  \
  $(if $(findstring q,$(MFLAGS)),, \
    $(if $(filter-out 0,$(r)),$(error error while executing sub-make $(1) (targets: $(2))),) \
  )
endef

# invoke make prestages if it has not been done already
# use a key that identifies the local project, allowing to nest
# projects that use this set of makefiles
prestage_key := $(shell basename $$PWD)

ifneq ($(EXEC_PRESTAGE),$(prestage_key))
  # ensure MAKECMDGOALS is not empty, otherwise the following checks would not work
  # and prestages would not be executed if no target is specified
  ifeq ($(MAKECMDGOALS),)
    MAKECMDGOALS := all
  endif

  # only call prestages if none of the following targets is called
  ifneq ($(filter-out help% menuconfig defconfig% clean% %clean githooks check_coding_style check_build_tools check_user_tools,$(MAKECMDGOALS)),)
    # check if clean targets are mixed with other targets that require prestages to be executed
    ifneq ($(filter clean% %clean,$(MAKECMDGOALS)),)
      $(error Mixing clean with other targets is not supported by the build system)
    endif

    $(call prestage,stage0,prepare_deps $(MAKECMDGOALS))
    $(call prestage,stage1,prepare_deps)

    $(call pdebug0,prestage done)
  endif
endif


#######################################
###   second stage 'make targets'   ###
#######################################

include $(scripts_dir)/Makefile.compile


###############################
###   verbosity and debug   ###
###############################

V ?= 0

ifeq ($(V),0)
  QBUILD := @
  QUTIL := @
endif

ifeq ($(call cond_ge,$(V),1),1)
  QBUILD :=
  QUTIL := @
endif

ifeq ($(call cond_ge,$(V),2),1)
  QBUILD :=
  QUTIL :=
endif

# print DEBUG message
#
#	$(call pdebug,<msg>)
ifeq ($(call cond_ge,$(V),3),1)
  define pdebug0
    $(info $1)
  endef
endif

ifeq ($(call cond_ge,$(V),4),1)
  define pdebug1
    $(info $1)
  endef
endif

ifeq ($(call cond_ge,$(V),5),1)
  define pdebug2
    $(info $1)
  endef
endif


################
###   init   ###
################

# include config file if defined
ifneq ("$(config)","")
  # warn if $(config) does not exist and more than the following targets are called
  ifneq ($(filter-out menuconfig defconfig% clean% %clean,$(MAKECMDGOALS)),)
    ifeq ("$(wildcard $(config))","")
      $(warning $(config) does not exist, run $$make menuconfig or $$make defconfig-* first)
    endif
  endif

  -include $(config)
endif

# check project type
ifneq ($(project_type),c)
  ifneq ($(project_type),cxx)
    $(error invalid $$(project_type), choose either 'c' or 'cxx')
  endif
endif

# init build system variables
all_flags := cflags cxxflags cppflags asflags ldflags archflags ldlibs hostcflags hostcxxflags hostcppflags hostasflags hostldflags hostarchflags hostldlibs yaccflags lexflags gperfflags

obj_types := obj obj-nobuiltin hostobj hostobj-nobuiltin
lib_types := lib hostlib
bin_types := bin hostbin
all_types := $(obj_types) $(lib_types) $(bin_types)

all_build_tools := cc cxx as ld ar hostcc hostcxx hostas hostld hostar lex yacc gperf
all_user_tools := $(tool_deps)

# init global flag variables
$(foreach flag,$(all_flags), \
    $(eval $(flag) := ) \
)

# init global variables for list of objects, libraries and executables
$(foreach type,$(supported_types), \
	$(eval $(type) :=) \
)

# disable built-in rules
.SUFFIXES:

# disable removal of temporary files
.SECONDARY:

# init source and build tree
$(call set_default,BUILD_TREE, $(default_build_tree))
$(call set_default,SRC_TREE, .)

build_tree := $(patsubst %/,%,$(BUILD_TREE))
src_tree := $(patsubst %/,%,$(SRC_TREE))

# init variables for directory traversal
build := $(scripts_dir)/Makefile.build
included :=

# set default values for tools
$(call set_default,CC, gcc)
$(call set_default,CXX, g++)
$(call set_default,AS, as)
$(call set_default,LD, ld)
$(call set_default,AR, ar)

$(call set_default,HOSTCC, gcc)
$(call set_default,HOSTCXX, g++)
$(call set_default,HOSTAS, as)
$(call set_default,HOSTLD, ld)
$(call set_default,HOSTAR, ar)

$(call set_default,LEX, flex)
$(call set_default,YACC, bison)
$(call set_default,GPERF, gperf)

cc := $(QBUILD)$(CC)
cxx := $(QBUILD)$(CXX)
as := $(QBUILD)$(AS)
ld := $(QBUILD)$(LD)
ar := $(QBUILD)$(AR)

hostcc := $(QBUILD)$(HOSTCC)
hostcxx := $(QBUILD)$(HOSTCXX)
hostas := $(QBUILD)$(HOSTAS)
hostld := $(QBUILD)$(HOSTLD)
hostar := $(QBUILD)$(HOSTAR)

lex := $(QBUILD)$(LEX)
yacc := $(QBUILD)$(YACC)
gperf := $(QBUILD)$(GPERF)
gperf_c_header := $(QBUILD)$(scripts_dir)/gperf_c_header.sh
gperf_cxx_header := $(QBUILD)$(scripts_dir)/gperf_cxx_header.sh
versionheader := $(QBUILD)$(scripts_dir)/version_header.sh

echo := @echo
printf := @printf
rm := $(QUTIL)rm -rf
mkdir := $(QUTIL)mkdir -p
touch := $(QUTIL)touch
cp := $(QUTIL)cp
mv := $(QUTIL)mv
grep := $(QUTIL)grep
sym_link := $(QUTIL)ln -s


###########################
###   default targets   ###
###########################

# fake target as default target
.PHONY: all
all: check_user_tools check_build_tools check_config dotclang

# target used to force recipe execution of dependent targets
.PHONY: force

# dummy target for non-existent command files
%.cmd:
	@:

ifneq ("$(githooks_tree)","")
# ensure githook links exists
.PHONY: githooks
.SILENT: githooks
githooks:
	$(call cmd_run_script, \
		repo_root=$$(git rev-parse --show-toplevel); \
		\
		for hook in style mantis util_print pre-commit post-commit; do \
		  test -e "$(githooks_tree)/$${hook}" || { echo $(githooks_tree)/$${hook} does not exist; exit 1; }; \
		  ln -frs $(githooks_tree)/$${hook} $${repo_root}/.git/hooks/$${hook}; \
		done \
	)

# check coding style
.PHONY: check_coding_style
check_coding_style:
	$(call cmd_run_script,${githooks_tree}/pre-commit $(shell find -type f | grep -v -e '\./\.git/' -e '\./build/'))

all: githooks
endif

# dummy target used to build targets that are not always
# listed as dependencies, e.g. generated header files
prepare_deps:
	@:

# check if all build tools are available
check_build_tools_error := "can't find \"$${val}\", ensure the variables $${id} or CONFIG_$${id} to be initialised correctly"

build_tools :=
$(foreach tool,$(all_build_tools), \
	$(eval build_tools += $(call upper_case,$(tool))=$(subst @,,$($(tool)))) \
)

.PHONY: check_build_tools
check_build_tools:
	$(call cmd_run_script, \
		@r=0; \
		for tool in $(build_tools); do \
			id=$$(echo $${tool} | cut -d '=' -f 1); \
			val=$$(echo $${tool} | cut -d '=' -f 2); \
			test -n "$$(which $${val})" || (echo $(check_build_tools_error); exit 1); \
			test $${?} -eq 1 && r=1; \
		done; \
		exit $${r}; \
	)

# check if all user tools are available
check_user_tools_error := "can't find \"$${tool}\", ensure it is installed"

.PHONY: check_user_tools
check_user_tools:
	$(call cmd_run_script, \
		@r=0; \
		for tool in $(all_user_tools); do \
			test -n "$$(which $${tool})" || (echo $(check_user_tools_error); exit 1); \
			test $${?} -eq 1 && r=1; \
		done; \
		exit $${r} \
	)

# check if $(config) file is present
.PHONY: check_config
check_config:
ifneq ($(shell test -e $(config) && echo $(config)),$(config))
	$(call error,$(config) does not exist, please run $$make menuconfig or $$make defconfig-<target> first)
endif

# include dependency files
include $(shell find $(build_tree)/ -type f -name \*.d 2>/dev/null)

# config system targets
ifeq ("$(use_config_sys)","y")
  ifneq ("$(config_ftype)","")
    config_header := $(build_tree)/config/config.h

    mconfig_src := $(scripts_dir)/mconf
    mconfig := $(build_tree)/$(mconfig_src)/mconfig
    confheader_src := $(scripts_dir)/mconf
    confheader := $(build_tree)/$(confheader_src)/confheader
    fixdep_src := $(scripts_dir)/fixdep
    fixdep := $(build_tree)/$(fixdep_src)/fixdep

    config_tools := $(fixdep) $(mconfig) $(confheader)

    fixdep := $(QBUILD)$(fixdep)

configtools: configtools_unavailable := y
configtools: $(config_tools)

$(config_header): $(config) configtools
	$(call compile_file,KCONFIG_CONFIG=$(config) $(confheader) $(config_ftype) $(dir $(config_header))fixdep $(config_header))

all: $(config_header)
prepare_deps: $(config_header)

.PHONY: menuconfig
menuconfig: check_build_tools configtools
	$(call cmd_run_script,KCONFIG_CONFIG=$(config) $(mconfig) $(config_ftype))

  endif
else
  configtools_unavailable := y
endif

# version header
version_header := $(build_tree)/version.h

.PHONY: versionheader
versionheader:
	$(call cmd_run_script,$(versionheader) $(version_header))

all: versionheader

# default config targets
ifneq ("$(config_tree)","")
config_files = $(notdir $(wildcard $(config_tree)/*))

$(foreach cfg, $(config_files), \
	$(call gen_rule_basic,cmd_defconfig,defconfig-$(cfg),$(config_tree)/$(cfg)) \
)
endif

# update .clang file
.PHONY: dotclang
dotclang:
	$(call cmd_run_script,$(echo) $(cppflags) $(hostcppflags) | grep -o -e "-I[ \t]*[a-zA-Z0-9_/\.]*" > .clang || true)

# help for the build system
help-buildsys:
	$(printf) "   \033[1m\033[4mtop-level Makefile syntax\033[0m\n"
	$(printf) "\n"
	$(printf) "     \033[1mrequired variables\033[0m\n"
	$(printf) "         %25s\t%s\n" "project_type" "define the type of the project [c|cxx]"
	$(printf) "         %25s\t%s\n" "scripts_dir" "directory containing the build system scripts"
	$(printf) "         %25s\t%s\n" "default_build_tree" "default target directory for builds, if not defined through BUILD_TREE"
	$(printf) "         %25s\t%s\n" "src_dirs" "list of space-separated directories used for the project sources"
	$(printf) "         %25s\t%s\n" "use_config_sys" "define whether to use the config system [y|n]"
	$(printf) "         %25s\t%s\n" "config_ftype" "name of configure files, e.g. Pconfig, only required if 'use_config_sys' is set to 'y'"
	$(printf) "         %25s\t%s\n" "config" "name of the project configuration, e.g. .config, only required if 'use_config_sys' is set to 'y'"
	$(printf) "\n"
	$(printf) "     \033[1moptional variables\033[0m\n"
	$(printf) "         %25s\t%s\n" "config_tree" "directory containing project configurations, used with 'defconfig-*' targets"
	$(printf) "         %25s\t%s\n" "githooks_tree" "directory containing git hooks"
	$(printf) "         %25s\t%s\n" "tool_deps" "list of space-separated tools that are required to properly execute the project"
	$(printf) "\n\n"
	$(printf) "   \033[1m\033[4msub-directory Makefile syntax\033[0m\n"
	$(printf) "\n"
	$(printf) "      \033[1mdefining build targets\033[0m\n"
	$(printf) "         %25s\t%s\n" "[host]obj-y" "define target object files, also combined into ./obj.o"
	$(printf) "         %25s\t%s\n" "[host]lib-y" "define target libraries"
	$(printf) "         %25s\t%s\n" "[host]bin-y" "define target binaries"
	$(printf) "         %25s\t%s\n" "<target>-y" "specify the objects required to build the compound object <target>"
	$(printf) "\n"
	$(printf) "             - prefixed \"host\" indicates to use host compiler tools\n"
	$(printf) "             - [host]obj-y can take a directory as \"obj-y := <dir>/\"\n"
	$(printf) "                  this builds <dir>/obj.o and adds <dir>/ to subdir-y\n"
	$(printf) "\n"
	$(printf) "      \033[1mdefining sub-directories\033[0m\n"
	$(printf) "         %25s\t%s\n" "subdir-y" "define sub-directories to include"
	$(printf) "\n"
	$(printf) "      \033[1mdefining flags\033[0m\n"
	$(printf) "         %25s\t%s\n" "[host]<flag>-y" "specified flags apply to  all targets within the current directory"
	$(printf) "         %25s\t%s\n" "<target>-[host]<flag>[-y]" "specified flags only apply to <target>"
	$(printf) "         %25s\t%s\n" "subdir-[host]<flag>[-y]" "specified flags apply to all sub-directories"
	$(printf) "         %25s\t%s\n" "<subdir>-[host]<flag>]-y]" "specified flags only apply to <subdir>"
	$(printf) "\n"
	$(printf) "         \033[1m%15s\033[0m\n" "<flag>"
	$(printf) "         %25s\t%s\n" "cflags" "c compiler flags"
	$(printf) "         %25s\t%s\n" "cxxflags" "c++ compiler flags"
	$(printf) "         %25s\t%s\n" "cppflags" "c pre-processor flags"
	$(printf) "         %25s\t%s\n" "asflags" "assembler flags"
	$(printf) "         %25s\t%s\n" "ldflags" "linker flags"
	$(printf) "         %25s\t%s\n" "ldlibs" "compiler flags when it is supposed to invoke the linker"
	$(printf) "         %25s\t%s\n" "archflags" "architecture specific flags"
	$(printf) "         %25s\t%s\n" "yaccflags" "yacc flags"
	$(printf) "         %25s\t%s\n" "lexflags" "lex flags"
	$(printf) "         %25s\t%s\n" "gperfflags" "gperf flags"
	$(printf) "\n"
	$(printf) "      \033[1musable variables\033[0m\n"
	$(printf) "         %25s\t%s\n" "src_tree" "source tree root"
	$(printf) "         %25s\t%s\n" "loc_src_tree" "the current directory"
	$(printf) "         %25s\t%s\n" "build_tree" "build tree root"
	$(printf) "         %25s\t%s\n" "loc_build_tree" "build tree for the current directory"
	$(printf) "\n\n"
	$(printf) "   \033[1m\033[4menvironment variables\033[0m\n"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "V" "change verbosity, default = 0"
	$(printf) "         %25s\t%s\n" "WHATCHANGED" "if set compile commands will indicate why they are rebuild"
	$(printf) "         %25s\t%s\n" "BUILD_TREE" "define output directory"
	$(printf) "         %25s\t%s\n" "SRC_TREE" "define source directory"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "[HOST]CC"
	$(printf) "         %25s\t%s\n" "[HOST]CXX"
	$(printf) "         %25s\t%s\n" "[HOST]AS"
	$(printf) "         %25s\t%s\n" "[HOST]LD"
	$(printf) "         %25s\t%s\n" "[HOST]AR"
	$(printf) "         %25s\t%s\n" "LEX"
	$(printf) "         %25s\t%s\n" "YACC"
	$(printf) "         %25s\t%s\n" "GPERF"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "[HOST]CFLAGS"
	$(printf) "         %25s\t%s\n" "[HOST]CXXFLAGS"
	$(printf) "         %25s\t%s\n" "[HOST]CPPFLAGS"
	$(printf) "         %25s\t%s\n" "[HOST]LDFLAGS"
	$(printf) "         %25s\t%s\n" "[HOST]LDLIBS"
	$(printf) "         %25s\t%s\n" "[HOST]ASFLAGS"
	$(printf) "         %25s\t%s\n" "[HOST]ARCHFLAGS"
	$(printf) "         %25s\t%s\n" "LEXFLAGS"
	$(printf) "         %25s\t%s\n" "YACCFLAGS"
	$(printf) "         %25s\t%s\n" "GPERFFLAGS"
	$(printf) "\n\n"
	$(printf) "   \033[1m\033[4mspecial targets\033[0m\n"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "<path>/<target>.i" "build pre-processed target file"
	$(printf) "         %25s\t%s\n" "<path>/<target>.S" "build assembly target file"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "menuconfig" "graphical configuration"
	$(printf) "         %25s\t%s\n" "defconfig-*" "apply default configuration, requires the 'config_tree' variable"
	$(printf) "\n"
	$(printf) "         %25s\t%s\n" "check_build_tools" "test if all build tools are available"
	$(printf) "         %25s\t%s\n" "check_user_tools" "test if all externally required tools, define in 'tool_deps', are available"
	$(printf) "         %25s\t%s\n" "check_config" "test if the config file defined in 'config' is accessible"


######################################
###   finally traverse Makefiles   ###
######################################

# start subdirectory traversal
# 	if subdir-y is empty include '.' (within $(src_tree))
$(if $(src_dirs), \
	$(call dinclude,$(src_dirs) $(mconfig_src) $(fixdep_src) $(confheader_src)) \
	, \
	$(error $$(src_dirs) is empty, please define initial source directories) \
)
# The TARGET variable determines what target system the application is 
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

ifeq ($(CONFIG), xs2)
	TARGET = XCORE-200-EXPLORER
endif
ifeq ($(CONFIG), xs2_300)
	TARGET = XCORE-200-EXPLORER-300.xn
endif
ifeq ($(CONFIG), xs3)
	TARGET = XCORE-AI-EXPLORER
endif
ifeq ($(CONFIG), xs3_375)
	TARGET = XCORE-AI-EXPLORER-375.xn
endif

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to 
# the project name

APP_NAME =

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS_xs2      = $(EXTRA_BUILD_FLAGS) -O0 -g -save-temps
XCC_FLAGS_xs2_300 = $(EXTRA_BUILD_FLAGS) -O0 -g -save-temps
XCC_FLAGS_xs3      = $(EXTRA_BUILD_FLAGS) -O0 -g -save-temps
XCC_FLAGS_xs3_375 = $(EXTRA_BUILD_FLAGS) -O0 -g -save-temps

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_spdif


#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common

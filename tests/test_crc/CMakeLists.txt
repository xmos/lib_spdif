cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_crc)

set(APP_HW_TARGET XK-EVK-XU316)

set(APP_INCLUDES src)

set(APP_COMPILER_FLAGS -O3 -report -g)

include(${CMAKE_CURRENT_LIST_DIR}/../test_deps.cmake)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

XMOS_REGISTER_APP()

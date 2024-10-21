cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(spdif_rx_analyse)

set(APP_HW_TARGET           xcore_ai_generic_500.xn)

include(${CMAKE_CURRENT_LIST_DIR}/test_deps.cmake)

set(APP_COMPILER_FLAGS      -O2
                            -report
                            -g
                            -DDEBUG_PRINT_ENABLE=1
                            -DTILE=0)

set(APP_PCA_ENABLE          ON)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

XMOS_REGISTER_APP()

cmake_minimum_required(VERSION 3.21)

include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_PCA_ENABLE          ON)

set(CONFIGS                 XS2_300
                            XS3_300)

set(HW_TARGETS              XCORE-200-EXPLORER-300.xn
                            XCORE-AI-EXPLORER-300.xn)

foreach(CONFIG IN LISTS CONFIGS)
    list(FIND CONFIGS "${CONFIG}" FOUND_INDEX)
    list(GET HW_TARGETS ${FOUND_INDEX} XN_FILE)
    message(STATUS "XN_FILE ${XN_FILE} found in config ${CONFIG} index ${FOUND_INDEX}")

    project(test_rx_${CONFIG})
    set(APP_HW_TARGET           ${XN_FILE})
    set(APP_COMPILER_FLAGS_${CONFIG}
                                -O3
                                -report
                                -g
                                )

    XMOS_REGISTER_APP()

    unset(APP_COMPILER_FLAGS_${CONFIG})
endforeach()


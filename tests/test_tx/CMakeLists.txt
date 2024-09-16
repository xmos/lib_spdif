cmake_minimum_required(VERSION 3.21)

include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_PCA_ENABLE          ON)

# set(CONFIGS                 XS2_300
#                             XS3_300)
# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON SAM_FREQS_LIST GET ${JSON_CONTENT} SAM_FREQS)
string(JSON CONFIG_LIST GET ${JSON_CONTENT} CONFIG)

# Convert JSON lists to CMake lists
string(JSON NUM_SAM_FREQS LENGTH ${SAM_FREQS_LIST})
string(JSON NUM_CONFIGS LENGTH ${CONFIG_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_SAM_FREQS "${NUM_SAM_FREQS} - 1")
math(EXPR NUM_CONFIGS "${NUM_CONFIGS} - 1")

foreach(i RANGE 0 ${NUM_CONFIGS})
    message(STATUS IDX:${i})
    string(JSON CONFIG GET ${CONFIG_LIST} ${i})
    message(STATUS CONFIG:${CONFIG})
    string(JSON ARCH GET ${CONFIG} ARCH)
    string(JSON CORE_FREQ GET ${CONFIG} CORE_FREQ)
    string(JSON XN_FILE GET ${CONFIG} XN_FILE)

    foreach(j RANGE 0 ${NUM_SAM_FREQS})
        string(JSON SAM_FREQ GET ${SAM_FREQS_LIST} ${j})
        set(CONFIG "${ARCH}_${CORE_FREQ}_${SAM_FREQ}")

        message(STATUS "CONFIG ${CONFIG} - XN_FILE ${XN_FILE} ARCH ${ARCH} CORE_FREQ ${CORE_FREQ}")


        project(test_rx_${CONFIG})
        set(APP_HW_TARGET           ${XN_FILE})
        set(APP_COMPILER_FLAGS_${CONFIG}
                                    -O3
                                    -report
                                    -g
                                    -DSAMPLE_FREQUENCY_HZ={sam_freq}"
                                    -DCHAN_RAMP_0={audio[0][1]}"
                                    -DCHAN_RAMP_1={audio[1][1]}"
                                    -DNO_OF_SAMPLES={no_of_samples}"
                                    -DMCLK_FREQUENCY={mclk_freq}",
                                    )

        XMOS_REGISTER_APP()

        unset(APP_COMPILER_FLAGS_${CONFIG})


cmake_minimum_required(VERSION 3.21)

include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_PCA_ENABLE          ON)

set(CONFIGS                 XS2_300
                            XS2_500
                            XS3_375
                            XS3_600)
set(HW_TARGETS              XCORE-200-EXPLORER-300.xn
                            XCORE-200-EXPLORER
                            XCORE-AI-EXPLORER-375.xn
                            XCORE-AI-EXPLORER)


foreach(CONFIG IN LISTS CONFIGS)
    list(FIND CONFIGS "${CONFIG}" FOUND_INDEX)
    list(GET HW_TARGETS ${FOUND_INDEX} XN_FILE)
    message(STATUS "XN_FILE ${XN_FILE} found in config ${CONFIG} index ${FOUND_INDEX}")

    project(test_tx_${CONFIG})
    set(APP_HW_TARGET           ${XN_FILE})
    set(APP_COMPILER_FLAGS_${CONFIG}
                                -O3
                                -report
                                -g
                                )

    XMOS_REGISTER_APP()

    unset(APP_COMPILER_FLAGS_${CONFIG})
    unset(APP_HW_TARGET)
endforeach()


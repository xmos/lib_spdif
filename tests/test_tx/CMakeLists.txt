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

# Extract global settings
string(JSON RAMP0 GET ${JSON_CONTENT} RAMP0)
string(JSON RAMP1 GET ${JSON_CONTENT} RAMP1)
string(JSON NO_OF_SAMPLES GET ${JSON_CONTENT} NO_OF_SAMPLES)


foreach(i RANGE 0 ${NUM_CONFIGS})
    message(STATUS IDX:${i})
    string(JSON CONFIG GET ${CONFIG_LIST} ${i})
    message(STATUS CONFIG:${CONFIG})
    string(JSON ARCH GET ${CONFIG} ARCH)
    string(JSON CORE_FREQ GET ${CONFIG} CORE_FREQ)
    string(JSON XN_FILE GET ${CONFIG} XN_FILE)

    foreach(j RANGE 0 ${NUM_SAM_FREQS})
        string(JSON SAM_FREQ GET ${SAM_FREQS_LIST} ${j})

        math(EXPR MCLK_48 "${SAM_FREQ} % 48000")
        if(${MCLK_48} MATCHES 0)
            set(MCLK_FREQ 24576000)
        else()
            set(MCLK_FREQ 22579200)
        endif()

        set(CONFIG "${ARCH}_${CORE_FREQ}_${SAM_FREQ}")

        message(STATUS "XN_FILE: ${XN_FILE} ARCH: ${ARCH} CORE_FREQ: ${CORE_FREQ} SAM_FREQ: ${SAM_FREQ} MCLK_FREQ: ${MCLK_FREQ}")

        project(test_rx_${CONFIG})
        set(APP_HW_TARGET           ${XN_FILE})
        set(APP_COMPILER_FLAGS_${CONFIG}
                                    -O3
                                    -report
                                    -g
                                    -DSAMPLE_FREQUENCY_HZ=${SAM_FREQ}
                                    -DCHAN_RAMP_0=${RAMP0}
                                    -DCHAN_RAMP_1=${RAMP1}
                                    -DNO_OF_SAMPLES=${NO_OF_SAMPLES}
                                    -DMCLK_FREQUENCY=${MCLK_FREQ}
                                    )

        XMOS_REGISTER_APP()

        unset(APP_COMPILER_FLAGS_${CONFIG})
    endforeach()
endforeach()

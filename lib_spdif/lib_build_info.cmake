set(LIB_NAME lib_spdif)

set(LIB_VERSION 7.0.0)

set(LIB_INCLUDES api src)
set(LIB_COMPILER_FLAGS  -O3
                        -Wall
                        -Wextra
                        -Wshadow
                        -Wconversion
                        -Wdiv-by-zero
                        -Wfloat-equal
                        -Wsign-compare)

set(LIB_COMPILER_FLAGS_SpdifTransmitReconfigPort.xc -O3 -Wno-unusual-code)
set(LIB_COMPILER_FLAGS_spdif_rx.xc -O3 -Wno-unusual-code)

set(LIB_DEPENDENT_MODULES "")

XMOS_REGISTER_MODULE()

set(LIB_NAME lib_spdif)
set(LIB_VERSION 6.2.1)
set(LIB_INCLUDES api)
set(LIB_COMPILER_FLAGS -O3)
set(LIB_COMPILER_FLAGS_SpdifTransmitReconfigPort.xc -O3 -Wno-unusual-code)
set(LIB_COMPILER_FLAGS_spdif_rx.xc -O3 -Wno-unusual-code)
set(LIB_DEPENDENT_MODULES "")

XMOS_REGISTER_MODULE()

###################
test_rx application
###################

This application runs the S/PDIF receive function in one thread. The samples
received are passed via a channel to a second thread which, if the sample
passes a parity check, sends the sample out of a buffered port. This makes
the sample value available to the pyxsim testing framework.

The initial sample frequency estimate for the S/PDIF receiver can be set by
the compile-time constant SAMPLE_FREQ_ESTIMATE. This allows tests to vary
the starting conditions of the receiver by changing the initial position in
the sweep through the sample rates as it tries to lock on to the incoming
signal.

There is also a compile-time macro TEST_DTHREADS for the number of dummy
threads to run. The dummy threads are threads running in fast-mode that can
affect the scheduling of the other threads to test that the S/PDIF receive
thread can operate correctly when the chip is fully loaded with threads in
an application competing for all the available MIPS.

However, an even stricter test is currently performed: no dummy threads are
run, but the system frequency in the XN file is reduced to 300 MHz. This
provides 60 MIPS to each thread, which is less than would be available at
the standard system frequency when fully loaded with eight threads.

The S/PDIF receiver currently runs successfully in this scenario, so this
makes testing simpler because it is very time-consuming to simulate dummy
threads in pyxsim. If more instructions are needed in the time-critical
section of the receiver, dummy threads would need to be re-enabled and the
system frequency reset to a standard value to test a realistic thread
scheduling scenario.
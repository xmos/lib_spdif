################
rx_capture utils
################

The application and Python scripts in this directory provide a way to capture an
over-sampled S/PDIF input stream, which can be used as a recorded input to the
stream-based receive tests.

This application runs on the XK-AUDIO-316-MC-AB hardware. By default it captures
from the optical receive port, but can use co-axial instead if the preprocessor
definition OPTICAL=0 is set. When run, the application captures as many samples
as it can store by reading raw data sampled at 100 MHz from a buffered port
connected to the optical/co-axial input.

The application should be run with XSCOPE enabled to capture the output, which
consists of one 32-bit value per line representing the over-sampled input signal.

This captured output data is the input to the capture.py script, which will read
these raw data samples and generate a binary file representing the S/PDIF signal.
This binary data can be played-back at 100 MHz from a transmitter application or
a simulator thread to replay the S/PDIF input stream.

The readback.py script takes a binary recorded stream as input and outputs a
string representation of ones and zeros to allow manual inspection of the stream.

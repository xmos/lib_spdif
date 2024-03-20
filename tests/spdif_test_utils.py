# Copyright 2014-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from Pyxsim import SimThread
import os

#####
# These tests analyse the transitions rather than the pin value
# eg. '011101000' or '100010111' -> '10011100'
#####
PREAMBLE_Z = "10011100"
PREAMBLE_X = "10010011"
PREAMBLE_Y = "10010110"
TRANSITIONS_OK = "1111111111111111111111111111"
TEST_SUBFRAME = PREAMBLE_Y + TRANSITIONS_OK + TRANSITIONS_OK


def extract_preamble(subframe: int):
    pre = subframe & 0xC
    pre = (
        "Z"
        if pre == 0x8
        else "X"
        if pre == 0xC
        else "Y"
        if pre == 0x0
        else "{0:02b}".format(pre >> 2)
    )
    return pre


#####
# A SimThread to drive a clock signal on a port.
# Note: the frequency is how often to toggle the port so clocking the port
#       once a second will produce a signal with a 2 second period
#####
class Clock(SimThread):
    def __init__(self, port: str, freq_Hz: int, polarity=0):
        self._pin = polarity
        self._freq_Hz = freq_Hz
        self._interval_carry = 0
        self._port = port

    def run(self):
        time = self.xsi.get_time()
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            self._pin = 1 - self._pin
            self.xsi.drive_port_pins(self._port, self._pin)

    def _get_next_interval(self):
        tick = self.xsi._xsi._time_step * self.xsi._xsi.xe.freq * 1000000  # Hz from MHz
        interval = (tick + self._interval_carry) // self._freq_Hz
        self._interval_carry = (tick + self._interval_carry) % self._freq_Hz
        return interval


#####
# Python spdif receiver, used for testing the output from the spdif transmitter running in the simulator.
#####
class Spdif_rx(Clock):
    def __init__(self, port: str, sam_freq: int, no_of_samples: int):
        super().__init__(port, sam_freq)
        self._no_of_samples = no_of_samples

    def run(self):
        time = self.xsi.get_time()
        sample_counter = 0
        in_buff = ""
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            pin = self.xsi.sample_port_pins(self._port)
            in_buff = in_buff[-63:] + ("1" if self._pin ^ pin else "0")
            self._pin = pin
            if in_buff[:8] in [PREAMBLE_Z, PREAMBLE_X, PREAMBLE_Y]:
                print(sub_frame_string(sample_counter, in_buff))
            if in_buff[:8] == PREAMBLE_Y:
                sample_counter += 1
                if sample_counter >= self._no_of_samples:
                    os._exit(os.EX_OK)


#####
# Container class to provide as an input to the Spdif_tx class
#####
class Spdif_tx_stream:
    def __init__(self, data: bytearray, freq: int):
        self._data = data  # binary data representing the signal to be transmitted
        self._freq = freq  # frequency at which to transmit the individual bits in the binary data


#####
# Python transmitter used to drive a bit representation of spdif data into the simulator
#####
class Spdif_tx(Clock):
    def __init__(
        self, port: str, streams: list[Spdif_tx_stream], trigger_pin=None, polarity=0
    ):
        super().__init__(port, streams[0]._freq, polarity)
        self._streams = (
            streams  # byte array to drive on the given pin at the given frequency
        )
        self._trigger_pin = trigger_pin  # If provided with a pin it will wait for a ready signal from the xe before transmitting
        self._trigger_thread = False  # Other simthreads can call the trigger() method to signal to this thread to change stream

    def run(self):
        # Drives the bit representation of the signal byte-array, repeating forever, until the thread trigger is set
        def tx_bytes(signal_bytes: bytearray, delay: int):
            time = self.xsi.get_time()
            time += delay
            self.wait_until(time)

            while 1:
                for byte in signal_bytes:
                    for i in range(8):
                        time += self._get_next_interval()
                        self.wait_until(time)
                        bit = (byte >> i) & 0x1
                        self.xsi.drive_port_pins(self._port, bit)
                    if self._trigger_thread:
                        self._trigger_thread = False
                        return

        if self._trigger_pin is not None:
            self.wait_for_port_pins_change([self._trigger_pin])

        delay = 0
        for idx in range(len(self._streams)):
            stream = self._streams[idx]
            self._freq_Hz = stream._freq
            tx_bytes(stream._data, delay)
            # Delay will be random; for now this is approximately two passes through the sample rate sweep
            delay = 65e12

    def trigger_thread(self):
        self._trigger_thread = True


#####
# Monitors a 32bit wide port which the xe in the simulator is using to "display" how it has interpreted spdif data
# to the outside world.
#####
class Port_monitor(SimThread):
    def __init__(
        self,
        p_debug: str,
        p_debug_strobe: str,
        no_of_samples: int = 0,
        spdif_tx: Spdif_tx | None = None,
        print_frame: bool = False,
        check_frames: list | None = None,
    ):
        self._p_debug = p_debug  # 32 bit port the xe file is outputting data on
        self._p_debug_strobe = (
            p_debug_strobe  # 1 bit port the xe using to show new data on the debug port
        )
        self._no_of_samples = no_of_samples * 2  # should be * number of channels
        self._print_frame = (
            print_frame  # Print the frames to the terminal as they are received
        )
        self._check_frames = (
            check_frames  # Frames() to check against if internal checking is required
        )
        self._spdif_tx = spdif_tx  # Spdif_tx object so that a change of input stream can be triggered

    def run(self):
        def capture_subframes(cf):
            found = 0
            frames = []
            init_values = cf is None
            while self._no_of_samples == 0 or found < self._no_of_samples:
                self.wait_for_port_pins_change([self._p_debug_strobe])
                if self.xsi.sample_port_pins(self._p_debug_strobe) == 1:
                    debug = self.xsi.sample_port_pins(self._p_debug)
                    pre = extract_preamble(debug)
                    if found or pre == "Z":
                        sample = "{0:032b}".format(debug)[::-1]
                        frames.append(
                            f"{(found)//2} [{pre}] - {sample[4::]} {TRANSITIONS_OK}"
                        )
                        if not init_values:
                            init_values = cf.log_initial_value(
                                (debug & 0x0FFFFFF0) >> 4
                            )
                        if self._print_frame:
                            print(frames[-1])
                        found += 1
            return frames

        def check_block(frames, cf):
            success = True
            expect = cf.expect()
            expect = expect[: self._no_of_samples]
            for i in range(max(len(frames), len(expect))):
                expected = "-" if i >= len(expect) else expect[i]
                sub_frame = "-" if i >= len(frames) else frames[i]
                if sub_frame != expected:
                    print(f"Expected: {expected} Seen:     {sub_frame}")
                    success = False
            return success

        result = True
        iters = len(self._check_frames) if self._check_frames is not None else 1
        for idx in range(iters):
            if idx > 0:
                self._spdif_tx.trigger_thread()
                # Ignore the first samples that are produced after the stream changes because they can be corrupted
                for _ in range(32):
                    self.wait_for_port_pins_change([self._p_debug_strobe])
                    if self.xsi.sample_port_pins(self._p_debug_strobe) == 1:
                        _val = self.xsi.sample_port_pins(self._p_debug)

            try:
                cf = self._check_frames[idx]
            except IndexError:
                cf = None
            frames = capture_subframes(cf)
            if cf:
                check = check_block(frames, cf)
                result &= check

        if result:
            print("PASS")
        os._exit(os.EX_OK)


#####
# The Frames class constructs an S/PDIF signal either to feed into the simulator to test
# the receiver or to check an output against.
# TODO - this class currently uses strings, it would probably be better to use a byte array
#
# .log_initial_value( int value )
#          used by Port_monitor after the first frame has been observed so that when
#          .expect() is called to check checks are conducted against a matching
#
# .expect()
#          outputs an array of strings representing the expected decoded spdif signal
#
# .stream()
#          outputs a byte array representing the spdif signal that can be driven on a pin for
#          the simulator to decode back into spdif data
#
#####
class Frames:
    def __init__(
        self,
        sources=None,
        channels=None,
        no_of_blocks=0,
        # byte 0
        pro=False,
        digital_audio=True,
        copyright=False,
        preEmphasis="000",
        mode=0,
        # byte 1
        catagory_code="digital/digital converters",
        catagory="other",
        L_bit=False,
        # byte 2
        # byte 3
        sam_freq=44100,
        clock_accuracy="level II",
        # byte 4
        bit_depth=24,
        original_sam_freq=0,  # unknown
        # byte 5-23
        extra=None,  # List of bytes
    ):
        # self.expect = ""
        self._no_of_samples = no_of_blocks * 192
        self._samples = None
        self._initial_values = []
        if sources is not None:
            self._audio = sources
        elif channels is not None:
            self._audio = channels
        else:
            # Error no channels or sources
            pass
        self._validity_flag = []
        self._user_data = []
        self._channel_status = []
        for i, _ in enumerate(self._audio):
            self._validity_flag.append("0")
            self._user_data.append("0")
            self._channel_status.append(
                self._get_byte_0(pro, digital_audio, copyright, preEmphasis, mode)
                + self._get_byte_1(catagory_code, catagory, L_bit)
                + self._get_byte_2(
                    i + 1 if sources is not None else 0,
                    i + 1 if channels is not None else 0,
                )
                + self._get_byte_3(sam_freq, clock_accuracy)
                + self._get_byte_4(bit_depth, original_sam_freq)
                + self._get_byte_extra(extra)
            )

    def _get_byte_0(self, pro, digital_audio, copyright, preEmphasis, mode):
        byte = ""
        byte += "1" if pro else "0"
        byte += "1" if not digital_audio else "0"
        byte += "1" if not copyright else "0"
        byte += preEmphasis
        byte += "{:02b}".format(mode)
        return byte

    def _get_byte_1(self, catagory_code, catagory, L_bit):
        byte = ""
        if catagory_code == "digital/digital converters":
            byte += "010"
            if catagory == "other":
                byte += "1111"
            else:
                raise Exception(
                    "Unsupported device catagory, if input is correct please add support to Frames"
                )
        else:
            raise Exception(
                "Unsupported device catagory, if input is correct please add support to Frames"
            )
        byte += "1" if L_bit else "0"
        return byte

    def _get_byte_2(self, source_No, channel_No):
        byte = ""
        byte += "{:04b}".format(source_No)[::-1]
        byte += "{:04b}".format(channel_No)[::-1]
        return byte

    def _get_byte_3(self, sam_freq, clock_accuracy):
        byte = ""
        if sam_freq == 22050:
            byte = "0010"
        elif sam_freq == 44100:
            byte = "0000"
        elif sam_freq == 88200:
            byte = "0001"
        elif sam_freq == 176400:
            byte = "0011"
        elif sam_freq == 24000:
            byte = "0110"
        elif sam_freq == 48000:
            byte = "0100"
        elif sam_freq == 96000:
            byte = "0101"
        elif sam_freq == 192000:
            byte = "0111"
        else:
            raise Exception(
                "Unsupported Sample rate, if input is correct please add support to Frames"
            )
        if clock_accuracy == "level II":
            byte += "00"
        else:
            raise Exception(
                "Unsupported Clock accuracy, if input is correct please add support to Frames"
            )
        byte += "00"
        return byte

    def _get_byte_4(self, bit_depth, original_sam_freq):
        # there are 2 options for 20bits this needs sorting for tests that involve a bit depth of 20
        byte = ""
        byte += "1" if bit_depth > 20 else "0"
        if bit_depth in [20, 16]:
            byte += "100"
        elif bit_depth in [22, 18]:
            byte += "010"
        elif bit_depth in [23, 19]:
            byte += "001"
        elif bit_depth in [24, 20]:
            byte += "101"
        elif bit_depth in [21, 17]:
            byte += "011"
        else:
            byte += "000"
        if original_sam_freq == 0:
            byte += "0000"
        else:
            raise Exception(
                "Unsupported original sample rate, if input is correct please add support to Frames"
            )
        return byte

    def _get_byte_extra(self, extra):
        byte = ""
        if extra is None:
            for _ in range(19):
                byte += "00000000"
        else:
            raise Exception(
                "Unsupported extra data, if input is correct please add support to Frames"
            )
        return byte

    def log_initial_value(self, value):
        if len(self._initial_values) < len(self._audio):
            self._initial_values.append(value)
        return len(self._initial_values) == len(self._audio)

    def _construct_out(self):
        frames = []
        samples = []
        for i, chan in enumerate(self._audio):
            samples.append([])
            value = 0 if i >= len(self._initial_values) else self._initial_values[i]
            audio_func = Audio_func(chan[0], chan[1]).next
            for _ in range(self._no_of_samples):
                samples[i].append("{:024b}".format(((1 << 24) - 1) & value)[::-1])
                value = audio_func(value)
        for j, _ in enumerate(samples[0]):
            for i, _ in enumerate(samples):
                if i == 0 and j % 192 == 0:
                    pre = PREAMBLE_Z
                elif i == 0:
                    pre = PREAMBLE_X
                else:
                    pre = PREAMBLE_Y
                subframe = samples[i][j]
                subframe += self._validity_flag[i][j % len(self._validity_flag[i])]
                subframe += self._user_data[i][j % len(self._user_data[i])]
                subframe += self._channel_status[i][j % len(self._channel_status[i])]
                subframe += "1" if subframe.count("1") & 0x1 else "0"
                frame = pre + "".join(
                    clock + data for clock, data in zip(TRANSITIONS_OK, subframe)
                )
                frames.append(frame)
        return frames

    def expect(self):
        expect = []
        for i, subframe in enumerate(self._construct_out()):
            expect.append(sub_frame_string(i // len(self._audio), subframe))
        return expect

    def stream(self, quick_start_offset=0, polarity=0):
        lines = self._construct_out()
        stream = b""
        for line in lines[quick_start_offset:] + lines[:quick_start_offset]:
            byte = 0
            for bit in line[::-1]:
                bit = (byte & 0x1) if bit == "0" else 1 - (byte & 0x1)
                byte = (byte << 1) | bit
            stream += byte.to_bytes(8, "little")
        return stream


#####
# Provides a single place that determines how sub-frames are displayed. Takes a sample number and the subframe
# and outputs that as a string for printing and checking against.
#####
def sub_frame_string(sample_no, subframe):
    pre = subframe[:8]
    pre = (
        "Z"
        if pre == PREAMBLE_Z
        else "X"
        if pre == PREAMBLE_X
        else "Y"
        if pre == PREAMBLE_Y
        else pre
    )
    return f"{sample_no} [{pre}] - {subframe[9::2]} {subframe[8::2]}"


#####
# Audio_func provides a class that can be given a type of test signal, fixed, ramp, none etc. and a control value
# and output what the next sample value should be based off the previous sample value by calling .next(previous)
#
# The way the control value is used depends on the function type. Eg. ("ramp", 5) will output the previous value + 5
# and ("fixed", 5) will output 5 no matter what the previous value is. Future additions could be ("sine", value)
# where the control value is used to characterize the sine wave.
#####
class Audio_func:
    def __init__(self, type="none", value=0):
        _type = type.lower()
        if _type == "none":
            self.next = self._none
        elif _type == "fixed":
            self.next = self._fixed
        elif _type == "ramp":
            self.next = self._ramp
        else:
            raise Exception("Unsupported audio data type")
        self._value = value

    def _none(self, previous):
        return None

    def _fixed(self, previous):
        return self._value

    def _ramp(self, previous):
        return (previous + self._value) if previous is not None else None


#####
# Recorded_stream hold metadata about a bit stream representation of spdif data
#####
class Recorded_stream:
    def __init__(self, file_name, audio, sam_freq, sample_rate):
        self.file_name = (
            file_name  # the binary file to be interpreted as an spdif signal
        )
        self.audio = audio  # Audio_func() describing the expected signal
        self.sam_freq = sam_freq  # audio sample rate
        self.sample_rate = sample_rate  # signal sample rate


#####
# Returns the clock frequency for outputting audio at different sample rates
#####
def freq_for_sample_rate(sam_freq: int):
    freq_Hz = None
    no_of_channels = 2
    no_of_bits_per_sub_frame = 64  # 32 bits of data & 32 transitions
    if sam_freq in [44100, 48000, 88200, 96000, 176400, 192000]:
        freq_Hz = sam_freq * no_of_bits_per_sub_frame * no_of_channels
    return freq_Hz

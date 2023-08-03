# Copyright 2014-2023 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

from Pyxsim import SimThread
import os

class Clock(SimThread):
    """
    
    """
    def __init__(self,clock_port: str,freq_Hz: int):
        self._running = True
        self._tick = 0
        if (freq_Hz <= 500000000000000):
            self._double_freq_Hz = 2 * freq_Hz
        else:
            raise ValueError("Error: Frequency Unsupported - too high")
        self._interval_carry = 0
        self._clock_port = clock_port
    def run(self):
        time = self.xsi.get_time()
        while True:
            time += self._get_next_interval()
            self.wait_until(time)
            self._tick = 1 - self._tick

            if self._running:
                self.xsi.drive_port_pins(self._clock_port, self._tick)
                if self._tick:
                    self.on_high()
                else:
                    self.on_low()

    # Override these functions to trigger actions on clock high and low
    def on_high(self):
        pass

    def on_low(self):
        pass

    def _get_next_interval(self):
        interval = (1000000000000000 + self._interval_carry) // self._double_freq_Hz
        self._interval_carry = (1000000000000000 + self._interval_carry) % self._double_freq_Hz
        return interval

class Spdif_rx(Clock):
    """

    """
    def __init__(self,clock_port: str, spdif_out_port: str, sam_freq: int, mclk_freq: int, samples):
        super().__init__(clock_port, mclk_freq)
        self._spdif_out_port = spdif_out_port
        self._samples = samples
        self._pin = 0
        self._data = False
        self._in_buff = 0b0
        self._state = -1
        self._chan = 0
        self._divider = int(mclk_freq / (sam_freq * 128))
        self._div = 0

    def on_high(self):
        if self._div == 0:
            self._pin , in_normalised = self._normalise_input(self.xsi.sample_port_pins(self._spdif_out_port))
            self._data = not self._data

            if self._state <= 3:
                self._in_buff = ((self._in_buff << 1) | in_normalised) & 0b11111111
            elif self._data:
                self._in_buff |= in_normalised << (self._state - 4)
            elif in_normalised != 1:
                raise Exception("Error: no biphase transition", self._state, self._data)

            match self._state:
                case -1:
                    self._wait_for_signal()
                case 3:
                    if self._data:
                        self._check_preamble()
                        self._state += 1
                case 31:
                    if self._data and self._samples[self._chan].check(self._in_buff):
                        self._in_buff = 0x0
                        self._state = 0
                case _:
                    if self._data:
                        self._state += 1
                    elif in_normalised != 1:
                        
                        pass
        self._div = (self._div +1) % self._divider

    def _normalise_input(self, pin):
        return pin, self._pin ^ pin
    
    def _wait_for_signal(self):
        if self._in_buff == 0b10011100:
            self._in_buff = 0x0
            self._data = True
            self._state = 4

    def _check_preamble(self,):
        match self._in_buff:
            case 0b10011100:
                self._chan = 0
            case 0b10010011:
                self._chan = 0
            case 0b10010110:
                self._chan = 1
            case 0b0:
                # TODO this is a bit hacky make a cleaner exit fin / dead air
                print("PASS")
                os._exit(os.EX_OK)
            case _:
                raise Exception("Error: Unexpected preamble " + bin(self._in_buff))
        self._in_buff = 0x0

class Spdif_tx(Clock):
    """
    """
    def __init__(self,clock_port: str, spdif_in_port: str, freq_Hz: int, audio_info, chan_info, polarity):
        super().__init__(clock_port, freq_Hz)
        self._spdif_in_port = spdif_in_port
        self._audio_info = audio_info
        self._chan_info = chan_info
    
    def on_high(self):
        
        pass

class Chan_status():
    """
    """
    def __init__(
            self,
            #byte 0
            pro=False,
            digital_audio=True,
            copyright=False,
            preEmphasis="none",
            mode=0,
            #byte 1
            catagory_code="digital/digital converters",
            catagory="other",
            L_bit=False,
            #byte 2
            source_No=-1, # do not take into account
            channel_No=-1, # do not take into account
            #byte 3
            sam_freq=44100,
            clock_accuracy="level II",
            #byte 4
            bit_depth=24,
            original_sam_freq=0, # unknown
            #byte 5-23
            extra=None, # List of bytes
            ):
        source_No +=1 # this is just to have 0 indexed channel numbers as input
        channel_No +=1 # this is just to have 0 indexed channel numbers as input
        self._chan_info = []
        self._bit = 0
        self._byte = 0
        error_message="Unsupported option used"
        # byte 0
        byte = 0
        if pro:
            print(error_message)
        if not digital_audio:
            byte = byte | 0b01000000
        if not copyright:
            byte = byte | 0b00100000
        if preEmphasis != "none":
            print(error_message)
        if mode != 0:
            print(error_message)
        self._chan_info.append(byte)
        # byte 1
        byte = 0
        if catagory_code == "digital/digital converters":
            byte = byte | 0b01000000
        else:
            print(error_message)
        if catagory == "other":
            byte = byte | 0b00011110
        else:
            print(error_message)
        if L_bit:
            byte = byte | 0b00000001
        self._chan_info.append(byte)
        # byte 2
        byte = 0
        byte = byte | int('{:08b}'.format(source_No)[::-1], 2) & 0b11110000
        byte = byte | int('{:04b}'.format(channel_No)[::-1], 2) & 0b00001111
        self._chan_info.append(byte)
        # byte 3
        byte = 0
        match sam_freq:
            case 22050:
                sam_freq = 0b00100000
            case 44100:
                sam_freq = 0b00000000
            case 88200:
                sam_freq = 0b00010000
            case 176400:
                sam_freq = 0b00110000
            case 24000:
                sam_freq = 0b01100000
            case 48000:
                sam_freq = 0b01000000
            case 96000:
                sam_freq = 0b01010000
            case 192000:
                sam_freq = 0b01110000
            case _:
                print(error_message)
                sam_freq = 0b0000
        byte = byte | sam_freq
        if clock_accuracy != "level II":
            print(error_message)
        self._chan_info.append(byte)
        # byte 4
        byte = 0
        if bit_depth == 24:
            byte = byte | 0b11010000
        else:
            print(error_message)
        if original_sam_freq != 0:
            print(error_message)
        self._chan_info.append(byte)

        if extra != None:
            self._chan_info = self._chan_info + extra
        while len(self._chan_info) < 24:
            self._chan_info.append(0)
        # print("chan_info_________")
        # for index, b in enumerate(self._chan_info):
        #     print("byte " + format(index, '02') + " | " + format(b,'08b'))

    def _get_chan_info_bit(self):
        bit = self._chan_info[self._byte] >> (7 - self._bit) & 0b1
        self._bit = (self._bit + 1) % 8
        if self._bit == 0:
            self._byte = (self._byte + 1) % len(self._chan_info)
        return bit

class Chan_samples():
    """
    """
    def __init__(self,
                 audio_func = None,
                 validity_flag = None,
                 user_data = None,
                 chan_bit = None
                 ):
        self._audio = audio_func if audio_func != None else self._audio_func
        self._previous = None
        self._validity_flag = validity_flag if validity_flag != None else self._validity_flag
        self._user_data = user_data if user_data != None else self._user_data
        self._chan_bit = chan_bit if chan_bit != None else self._chan_bit
    def check(self, sample):
        expected = self._chan_bit() << 26
        expected |= self._user_data() << 25
        expected |= self._validity_flag() << 24
        audio = self._audio(self._previous)
        if audio == None:
            parity = (sample & 0x07FFFFFF).bit_count() & 0x1
            self._previous = sample & 0x00FFFFFF
            sample &= 0x0F000000
        else:
            self._previous = (((1<<24) -1) & audio)  & 0x00FFFFFF
            expected |= self._previous
            parity = expected.bit_count() & 0x1
        expected |= parity << 27

        if sample != expected:
            print("sample   = " +'{:028b}'.format(sample) + "\nexpected = "+'{:028b}'.format(expected))
            os._exit(os.EX_OK)
        # else:
        #     print(self._previous)
        #     print("sample   = " +'{:028b}'.format(sample) + "\nexpected = "+'{:028b}'.format(expected)+ "\n")
        return True
    
    #these functions are to work around issues with lambda functions and pickling on macOS
    def _audio_func(self, previous):
        return None
    def _validity_flag(self):
        return 0
    def _user_data(self):
        return 0
    def _chan_bit(self):
        return 0

class Audio_func():
    def __init__(self, type="none", value=0):
        match type.lower():
            case "none":
                self.next = self._none
            case "fixed":
                self.next = self._fixed
            case "ramp":
                self.next = self._ramp
            case _:
                raise Exception("audio data type not supported")
        self._value = value

    def _none(self, previous):
        return None

    def _fixed(self, previous):
        return self._value

    def _ramp(self, previous):
        return (previous + self._value) if previous != None else None

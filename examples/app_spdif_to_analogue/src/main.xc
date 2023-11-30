#include <xs1.h>
#include <platform.h>
#include "i2s.h"
#include "i2c.h"
//#include <print.h>
#include <spdif.h>
//#include <stdlib.h>
//#include <stdint.h>
//#include <stddef.h>
//#include <stdio.h>

#define SAMPLE_FREQUENCY (48000)
//#define MASTER_CLOCK_FREQUENCY (24576000)
#define DATA_BITS (32)

// I2S ports
on tile[1]: out buffered  port:32 p_dout[1] = {PORT_I2S_DAC0};
on tile[1]: out           port    p_bclk    = PORT_I2S_BCLK;
on tile[1]: out buffered  port:32 p_lrclk   = PORT_I2S_LRCLK;
on tile[1]: in            port    p_mclk    = PORT_MCLK_IN;
on tile[1]:               clock   clk_bclk  = XS1_CLKBLK_1;

// I2C ports
on tile[0]:               port    p_scl     = PORT_I2C_SCL;
on tile[0]:               port    p_sda     = PORT_I2C_SDA;

// Change these defines to control optical/coax and set the sample frequency.
#ifndef OPTICAL
#define OPTICAL               (0)
#endif

#if(OPTICAL)
on tile[0]: in            port    p_spdif_rx      = XS1_PORT_1O; // Optical rx
#else
on tile[0]: in            port    p_spdif_rx      = XS1_PORT_1N; // Coaxial rx
#endif

on tile[0]: out           port    p_ctrl          = XS1_PORT_8D;
on tile[0]:               clock   clk_spdif_rx    = XS1_CLKBLK_1;

/* Reference clock to external fractional-N clock multiplier */
on tile[0]: out           port    p_pll_ref       = PORT_PLL_REF;

#ifndef SAMPLE_BUFF_SIZE
/* Note, buffer index wrap code assumes this is a power of 2 */
#define SAMPLE_BUFF_SIZE 16
#endif

#define SAMPLE_COUNT ((48000/300))

/* The number of timer ticks to wait for the audio PLL to lock */
/* CS2100 lists typical lock time as 100 * input period */
#define     AUDIO_PLL_LOCK_DELAY     (40000000)
#define CS2100_I2C_DEVICE_ADDRESS    (0x4E)

// PCA9540B (2-channel I2C-bus mux) I2C Slave Address
#define PCA9540B_I2C_DEVICE_ADDR    (0x70)

// PCA9540B (2-channel I2C-bus mux) Control Register Values
#define PCA9540B_CTRL_CHAN_0        (0x04) // Set Control Register to select channel 0
#define PCA9540B_CTRL_CHAN_1        (0x05) // Set Control Register to select channel 1
#define PCA9540B_CTRL_CHAN_NONE     (0x00) // Set Control Register to select neither channel

#define CS2100_DEVICE_CONTROL       (0x02)
#define CS2100_DEVICE_CONFIG_1      (0x03)
#define CS2100_GLOBAL_CONFIG        (0x05)
#define CS2100_RATIO_31_24          (0x06)
#define CS2100_RATIO_23_16          (0x07)
#define CS2100_RATIO_15_08          (0x08)
#define CS2100_RATIO_07_00          (0x09)
#define CS2100_FUNC_CONFIG_1        (0x16)
#define CS2100_FUNC_CONFIG_2        (0x17)


void write_cs2100_reg(client interface i2c_master_if i2c, int reg_addr, int reg_data)
{
  i2c_regop_res_t result;
  //printf("Writing cs2100 reg ...\n");
  result = i2c.write_reg(CS2100_I2C_DEVICE_ADDRESS, reg_addr, reg_data);
  if (result != I2C_REGOP_SUCCESS) {
    printf("CS2100 I2C write reg failed\n");
  }
}

/* Configures the external audio hardware at startup */
void audio_hw_setup(client interface i2c_master_if i2c)
{
    i2c_regop_res_t result;

    // Wait for power supply to come up.
    delay_milliseconds(10);
  
    // Set the I2C Mux to switch to channel 1

    // I2C mux takes the last byte written as the data for the control register.
    // We can't send only one byte so we send two with the data in the last byte.
    // We set "address" to 0 below as it's discarded by device.
    result = i2c.write_reg(PCA9540B_I2C_DEVICE_ADDR, 0, PCA9540B_CTRL_CHAN_1);
    if (result != I2C_REGOP_SUCCESS) {
      printf("I2C Mux I2C write reg failed\n");
    }
    
    /* Enable init */
    write_cs2100_reg(i2c, CS2100_DEVICE_CONFIG_1, 0x07); // R-mod = 0, Aux out is LOCK, Enable Config 1
    write_cs2100_reg(i2c, CS2100_GLOBAL_CONFIG, 0x01); //  Enable Config 2
    write_cs2100_reg(i2c, CS2100_FUNC_CONFIG_1, 0x08); // No clock skip, Aux out push pull, ref clk div /2
    write_cs2100_reg(i2c, CS2100_FUNC_CONFIG_2, 0x00); // Stop clock output when unlocked, high multiplier mode (20.12)
    
    /* Multiplier is translated to 20.12 format by shifting left by 12 */
    // We want multiplier of x128 to take fs and mutiply up to make 128fs.
    // So we want d128 = 0x80 << 12 = 0x00080000
    write_cs2100_reg(i2c, CS2100_RATIO_31_24, 0x00);
    write_cs2100_reg(i2c, CS2100_RATIO_23_16, 0x08);
    write_cs2100_reg(i2c, CS2100_RATIO_15_08, 0x00);
    write_cs2100_reg(i2c, CS2100_RATIO_07_00, 0x00);

}

//static const unsigned g_sampRate = 48000;
//static const unsigned g_mclk = 48000 * 256;


void board_setup(void)
{
    set_port_drive_high(p_ctrl);

    // Drive control port to turn on 3V3.
    // Bits set to low will be high-z, pulled down.
    // MCLK_DIR = 0 => Use external PLL
    // EXT_PLL_SEL = 0 => Use CS2100 external PLL
    p_ctrl <: 0x20;

    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);
}

typedef enum bufferState
{
    BUFF_STATE_UNDERFLOW,
    BUFF_STATE_OVERFLOW,
    BUFF_STATE_NORMAL,
} bufferState_t;

/* Returns 1 for bad parity, else 0 */
static inline int BadParity(unsigned sample)
{
    unsigned X  = (sample >> 4);
    crc32(X, 0, 1);
    return X & 1;
}

#pragma unsafe arrays
void buffer_control(streaming chanend c_spdif, server i2s_frame_callback_if i_i2s)
{
    unsigned sampleBuffer[SAMPLE_BUFF_SIZE];
    unsigned sample;
    bufferState_t buffState = BUFF_STATE_UNDERFLOW;
    int bufferFill = 0;
    unsigned readPtr = 0;
    unsigned writePtr = 0;
    unsigned refClkVal = 0;
    //int sampleCount = 0;

    p_pll_ref <: refClkVal;

    //c_i2s <: 0;
    //c_i2s <: 0;

    while(1)
    {
        select
        {
            /* Receive an SPDIF sample */
            case c_spdif :> sample:
                refClkVal = ~refClkVal; // toggle pll ref clock value
                p_pll_ref <: refClkVal; // output to port

                if(BadParity(sample))
                {   
                    continue;      // Ignore sample
                }

/*                 sampleCount++;
                if(sampleCount == SAMPLE_COUNT)
                {
                    refClkVal = ~refClkVal;
                    sampleCount = 0;
                    p_pll_ref <: refClkVal;
                } */

                if(buffState == BUFF_STATE_OVERFLOW)
                {   
                    continue;      // Ignore sample
                }

                if(SPDIF_IS_FRAME_X(sample) || SPDIF_IS_FRAME_Z(sample))
                {
                    unsigned leftSample = SPDIF_RX_EXTRACT_SAMPLE(sample);
                    sampleBuffer[writePtr] = leftSample;
                    continue;
                }
                else if(SPDIF_IS_FRAME_Y(sample))
                {
                    /* Store samples */
                    writePtr++;
                    sampleBuffer[writePtr++] = SPDIF_RX_EXTRACT_SAMPLE(sample);

                    /* Wrap writePtr */
                    writePtr &= (SAMPLE_BUFF_SIZE -1);
                    bufferFill+=2;

                    /* Check if we need to go into overflow or can come out of underflow */
                    if(bufferFill > SAMPLE_BUFF_SIZE-1)
                    {
                        buffState = BUFF_STATE_OVERFLOW;
                    }
                    else if((buffState == BUFF_STATE_UNDERFLOW) && (bufferFill >= (SAMPLE_BUFF_SIZE >>1)))
                    {
                        /* Check if we can come out of underflow */
                        buffState = BUFF_STATE_NORMAL;
                    }
                }
        
            break;
            case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
              //i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY / (SAMPLE_FREQUENCY*2*DATA_BITS));
              i2s_config.mclk_bclk_ratio = 2;
              i2s_config.mode = I2S_MODE_I2S;
              // Complete setup
              break;
            case i_i2s.restart_check() -> i2s_restart_t restart:
              // Inform the I2S slave whether it should restart or exit
              restart = I2S_NO_RESTART;
              break;
            case i_i2s.receive(size_t n_chans, int32_t in_samps[n_chans]):
              break;
            case i_i2s.send(size_t num_out, int32_t samples[num_out]):
              // Provide a sample to send
              //break;
            /* i2s requests a sample */
            //case c_i2s :> int _:
                //c_i2s :> int _;    
                

                if(buffState == BUFF_STATE_UNDERFLOW)
                {
                    /* Underflowing - send back 0's */
                    //for(int i = 0; i < I2S_MASTER_NUM_CHANS_DAC; i++)
                    //{   
                        //c_i2s <: 0;
                        samples[0] = 0;
                        samples[1] = 0;
                    //}    
                }
                else
                {
                    //c_i2s <: sampleBuffer[readPtr++];
                    //c_i2s <: sampleBuffer[readPtr++];
                    samples[0] = sampleBuffer[readPtr++];
                    samples[1] = sampleBuffer[readPtr++];

                    /* Wrap read pointer */
                    readPtr &= (SAMPLE_BUFF_SIZE - 1);

                    bufferFill-=2;

                    if(bufferFill < 0)
                    {
                        buffState = BUFF_STATE_UNDERFLOW;
                    }

                    if((buffState == BUFF_STATE_OVERFLOW) && (bufferFill < (SAMPLE_BUFF_SIZE >> 1)))
                    {
                        buffState = BUFF_STATE_NORMAL;   
                    } 
                }
            break;
        }
    }
}

int main()
{
    streaming chan c_spdif;
    i2s_frame_callback_if i_i2s;
    i2c_master_if i_i2c[1];

    par
    {
        on tile[0]:
        {
          board_setup();
          audio_hw_setup(i_i2c[0]);
          spdif_rx(c_spdif, p_spdif_rx, clk_spdif_rx, SAMPLE_FREQUENCY);
        }
        on tile[0]: buffer_control(c_spdif, i_i2s);
        on tile[0]: i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        on tile[1]: i2s_frame_master(i_i2s, p_dout, 1, NULL, 0, DATA_BITS, p_bclk, p_lrclk, p_mclk, clk_bclk);
    }

}

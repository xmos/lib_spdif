#include <xs1.h>
#include <platform.h>
#include <xscope.h>
#include <stdio.h>
#include <xclib.h>

// Required
on tile[TILE]: in  buffered    port:32 p_spdif_rx    = XS1_PORT_1N; // SPDIF input port // mcaudio opt in // 1O is opt, 1N is coax
on tile[TILE]: clock                   clk_spdif_rx  = XS1_CLKBLK_1;

// Optional if required for board setup.
on tile[TILE]: out             port    p_ctrl        = XS1_PORT_8D;

void exit(int);

void board_setup(void)
{
    p_spdif_rx   :> void;
    //////// BOARD SETUP FOR XU316 MC AUDIO ////////
    
    set_port_drive_high(p_ctrl);
    
    // Drive control port to turn on 3V3.
    // Bits set to low will be high-z, pulled down.
    p_ctrl <: 0x20;
    
    // Wait for power supplies to be up and stable.
    delay_milliseconds(10);

    /////////////////////////////
}

#define CORE_CLOCK_MHZ 500
#define CLK_DIVIDE 1
// Define how many 32 bit samples to collect for analysis
#define SAMPLES 60000 //61140

#define PORT_PAD_CTL_4mA_SCHMITT   0x00920006


void printintBits(int word)
{
    unsigned mask = 0x80000000;
    for (int i = 0; i<32; i++)
    {
      if ((word & mask) == mask)
        printf("1");
      else
        printf("0");
      mask >>= 1;
    }
}

void spdif_rx_analyse(void)
{
    xscope_mode_lossless();
    // Define a clock source - core clock (800MHz) divided by (2*CLK_DIVIDE)
    configure_clock_xcore(clk_spdif_rx, CLK_DIVIDE);

    // Configure spdif rx port to be clocked from spdif_rx clock defined above.
    configure_in_port(p_spdif_rx, clk_spdif_rx);

    // Start the clock block running.
    start_clock(clk_spdif_rx);

    // Configure the pad if required (used for testing), xcore.ai only
    // Uncomment the following line to enable the schmitt trigger on the input pad.
    // asm volatile ("setc res[%0], %1" :: "r" (p_spdif_rx), "r" (PORT_PAD_CTL_4mA_SCHMITT));
    // Uncomment the following line to turn on the input pad pulldown.
    // asm volatile ("setc res[%0], %1" :: "r" (p_spdif_rx), "r" (0x000B)); // Turn on PULLDOWN
    // Uncomment the following line to turn on the input pad pullup.
    // asm volatile ("setc res[%0], %1" :: "r" (p_spdif_rx), "r" (0x0013)); // Turn on PULLUP
  
    // Delay a long time to make sure everything is settled
    delay_milliseconds(1/*000*/);
    
    printf("S/PDIF signal quality analyser.\n");
    
    float core_clock_ns = 1000/CORE_CLOCK_MHZ;
    
    unsigned sample_rate_MHz = CORE_CLOCK_MHZ/(CLK_DIVIDE*2);
    float sample_time_ns = (core_clock_ns * 2 * CLK_DIVIDE);
    printf("sample time = %fns\n", sample_time_ns); 
    
    printf("Sampling at %dMHz\n", sample_rate_MHz);
    
    unsigned samples[SAMPLES];
    // #pragma unsafe arrays
    // Sample the input port and load into array in memory
    for(unsigned i=0; i<SAMPLES; i++)
    {
        p_spdif_rx :> samples[i];
    }

    // Some potentially useful printing functions
    // for(int i=0; i<SAMPLES; i++)
    // {
    //     printf("Sample %d is 0x%08X\n", i, bitrev(samples[i]));
    // }

    // for(int i=0; i<SAMPLES; i++)
    // {
    //     printf("0x%08X,", samples[i]);
    // }
    // printf("\n");

    // for(int i=0; i<20; i++)
    // {
    //     printf("%08X ", bitrev(samples[i]));
    // }
    // printf("\n");
    // for(int i=0; i<20; i++)
    // {
    //     printintBits(bitrev(samples[i]));
    //     printf(" ");
    // }
    // printf("\n");
    
    // Now process the samples.
    // Look for pulses
    // Find and log all pulse lengths in an array and list if they are positive pulses (1s) or negative (0s).
    // Initially just add all pulse length results into an array.
    
    unsigned cur_value = samples[0] & 1; // record the value of the first pulse (LSB of samples[0])
    unsigned cur_sample;
    unsigned last_tran = 0;
    char pulse_lengths[4*SAMPLES];
    unsigned pulse_count = 0;
    unsigned t = 0;
    unsigned cur_bit;
    unsigned rising_count = 0;
    
    for(int i=0; i<SAMPLES; i++)
    {
        cur_sample = samples[i];
        //printf("Sample %d is 0x%08X\n", i, cur_sample);
        for(int j=0; j<32; j++)
        {
            cur_bit = (cur_sample >> j) & 1;
            if (cur_bit != cur_value) // transition
            {
                // Check there aren't too many transitions
                // Most transitions would be with 192kHz.
                if (pulse_count >= (4*SAMPLES))
                {
                    printf("Too many transitions found. QUIT.\n");
                    exit(1);
                }
                if (cur_value == 0) // rising edge
                {
                    rising_count++; 
                }
                if (rising_count > 1) // Don't start until we've seen two rising edges, so first pulse length recorded is always negative and ignores first pulse length which would be bogus.
                {
                    pulse_lengths[pulse_count] = t - last_tran;
                    //printf("Found pulse %d at time %d\n", pulse_count, t);
                    pulse_count++;
                }
                cur_value = cur_bit;
                last_tran = t;
            }
            t++;
        }
    }
    
/*     for(int i=0; i<pulse_count; i++)
    {
        printf("Pulse length[%d] = %d\n", i, pulse_lengths[i]);
    } */
        
    // Basic analysis of input.
    
    // Check signal is toggling
    if (pulse_count == 0)
    {
        printf("No transitions found. Signal is static. QUIT.\n");
        exit(1);
    }
    
    // Check there are a minimum total number of transitions
    if (pulse_count < (SAMPLES>>4))
    {
        printf("Too few transitions. QUIT.\n");
        exit(1);
    }
    
    // Build a histogram of pulse lengths
    unsigned pulse_histogram[128] = {0}; // count of how many pulses occurred for each pulse length. Pulse length is index into this array.

    unsigned hist_count = 0;
    unsigned min_pulse = 1000; // Minimum pulse length found
    unsigned max_pulse = 0; // Maximum pulse length found
    unsigned max_count = 0; // Maximum count of pulses in any bin
    for(int j=0; j<128; j++)
    {
        for(int i=0; i<pulse_count; i++)
        {
            unsigned pulse_len = pulse_lengths[i];
            if (pulse_len == j) // We found a pulse length equal to this bin
            {
                hist_count++;
            }
            if (pulse_len > max_pulse)
            {
                max_pulse = pulse_len;
            }
            if (pulse_len < min_pulse)
            {
                min_pulse = pulse_len;
            }
        }
        pulse_histogram[j] = hist_count;
        if (hist_count > max_count)
        {
            max_count = hist_count;
        }
        hist_count = 0;
    }
    
    //printf("histogram: max_count = %d, max_pulse = %d, min pulse = %d\n", max_count, max_pulse, min_pulse);

    // Need to scale the histogram here
    // Say we want max characters printed to be 100 
    // We will scale the graph by (max_count/100)
    unsigned scale = max_count/100;
    
    // Print the histogram
    printf("Pulse Length Histogram\n");
    printf("Pulse Length(ns), Count : Histogram graph\n");
    for(int j=min_pulse; j<(max_pulse+1); j++)
    {
        printf("%5.1f, %4d : ", (j*sample_time_ns), pulse_histogram[j]);
        for(int i=0; i<(pulse_histogram[j]/scale);i++) // Scaled print
        {
            printf("#");
        }
        printf("\n");
    }
    
    // Now look in the histogram for the gaps between pulse length groups (short, mid, long) where there were no pulses of intermediate length
    // Find all the groups of bins with consecutive 0s in. (ideally would be two groups).
    unsigned zeros = 0;
    unsigned zeros_start[10] = {0};
    unsigned zeros_len[10] = {0};    
    unsigned zeros_groups = 0;
    #define ZERO_THRESH 2 // Below what count do we consider as just noise (only for debug in noisy cables/systems)
    
    for(int j=min_pulse; j<max_pulse; j++)
    {
        if (zeros == 0)
        {
            if (pulse_histogram[j] <= ZERO_THRESH)
            {
                zeros = 1;
                zeros_start[zeros_groups] = j;
            }
        }
        else
        {
            if (pulse_histogram[j] > ZERO_THRESH)
            {
                zeros = 0;
                zeros_len[zeros_groups] = j - zeros_start[zeros_groups];
                zeros_groups++;
            }
        }
    }
    
    printf("Found %d groups of zeros bins in pulse lengths histogram:\n", zeros_groups);
    for(int i=0; i<zeros_groups; i++)
    {
        printf("Zeros group %d: start: %d, end: %d, length: %d\n", i, zeros_start[i], (zeros_start[i] + zeros_len[i] - 1), zeros_len[i]);
    }
    
    // Find the index of the longest two groups
    unsigned zeros_len_max[2] = {0};
    unsigned zeros_len_max_index[2] = {0};
    
    if (zeros_groups < 2)
    {
        printf("Found less than two groups of zeros, cannot discern between pulses. QUIT.\n");
        exit(1);
    }
    else // We have to find the longest two groups
    {
        for(int i=0; i<zeros_groups; i++)
        {
            if (zeros_len[i] > zeros_len_max[0])
            {
                // Mark the previous best as second best
                zeros_len_max[1] = zeros_len_max[0];
                zeros_len_max_index[1] = zeros_len_max_index[0];
                // Mark the latest as best
                zeros_len_max[0] = zeros_len[i];
                zeros_len_max_index[0] = i;
            }
            else if (zeros_len[i] > zeros_len_max[1])
            {
                // Mark the latest as second best
                zeros_len_max[1] = zeros_len[i];
                zeros_len_max_index[1] = i;
            }
            
        }
    }
    
    printf("Found two longest zero groups:\n");
    unsigned thresh[2] = {0}; // pulse width thresholds [0] = short-mid, [1] = mid-long
    
    for(int i=0;i<2;i++)
    {
        unsigned index = zeros_len_max_index[i];
        unsigned start = zeros_start[index];
        unsigned length = zeros_len[index];
        if (length < 3)
        {
            printf("Not a large enough separation between pulse length groups (<3). Cannot separate groups reliably. QUIT.\n");
            exit(1);
        }
        thresh[i] = start + (length/2);
        printf("Zero group %d, start: %d, end: %d, length: %d, threshold %d\n", i, start, (start+length-1), length, thresh[i]);
    }
    
    // We want the thresholds in pulse length order, if they are not, swap them.
    if (thresh[1] < thresh[0])
    {
        unsigned tmp = thresh[0];
        thresh[0] = thresh[1];
        thresh[1] = tmp;
    }
    
    printf("Pulse length thresholds (samples): short-mid = %d, mid-long = %d\n", thresh[0], thresh[1]);
    
    // Indexing: short = 0, medium = 1, long = 2
    
    // Find the sample rate
    // Look for preambles. All start with a long pulse, then disregard the next say eight pulses (some may be long)
    // So look for a long pulse, wait for eight pulses to make sure we're in the middle of a word. Then look for long pulse, make this time t0. ignore next eight pulses and look for long again.
    // A subframe might be 4 + (28*2) = 60 pulses long if transmitting all 1s.
    // Lets measure the time for 256 subframes, this could be 60*256 = 15360 pulses.
    unsigned first_long = 0;
    unsigned pre_count = 0;
    unsigned i_start, i_end;
    
    //printf("pulse_count = %d\n", pulse_count);
    
    for(int i=0; i<pulse_count; i++)
    {
        if (pulse_lengths[i] > thresh[1]) // Long
        {
            //printf("%d, %d\n",pulse_lengths[i], i);
            if (first_long == 0)
            {
                first_long = 1;
                i = i+8;
            }
            else
            {
                if (pre_count == 256)
                {
                    i_end = i;
                    break;
                }
                if (pre_count == 0)
                {
                    i_start = i; // get the index of the pulse count array that we are starting measuring time from
                }
                pre_count++;
                i = i+8;
            }
        }
    }
    
    // Sum up all the pulse times to get the total time
    unsigned t_pre256 = 0;
    for(int i=i_start; i<i_end; i++)
    {
        t_pre256 = t_pre256 + pulse_lengths[i];
    }
    
    float time_1ui_fl;
    float calc_sample_rate_khz;
    
    printf("t_pre256 = %d\n", t_pre256);
    
    // 256 preambles means 256 subframes so (256*64UI per subframe) = 16384UI
    // Total time is t_pre256 * sample time
    // So final is (t_pre256 * sample time)/16384
    time_1ui_fl = (float) (t_pre256*sample_time_ns)/16384;
    calc_sample_rate_khz = 1000000/(time_1ui_fl*128);
    
    printf("i_start = %d, i_end = %d, time_1ui_fl = %fns, calc_sample_rate = %.3fkHz\n", i_start, i_end, time_1ui_fl, calc_sample_rate_khz);
    printf("Measured sample rate = %.3fkHz\n", calc_sample_rate_khz);

    unsigned pos_len_tot[3] = {0}; // Positive length totals
    unsigned neg_len_tot[3] = {0}; // Negative length totals

    unsigned pos_len_count[3] = {0}; // Positive length count
    unsigned neg_len_count[3] = {0}; // Negative length count
    
    unsigned pos_min_len[3] = {1000,1000,1000};
    unsigned neg_min_len[3] = {1000,1000,1000};
    
    unsigned pos_max_len[3] = {0};
    unsigned neg_max_len[3] = {0};
    
    // First pulse length in the array is a negative pulse. Then they obviously alternate every pulse.
    // So all even indexes in the array are negative. All odd indexes are positive.
    
    for(int i=0; i<pulse_count; i++)
    {
        //printf("Pulse length[%d] = %d\n", i, pulse_lengths[i]);
        unsigned pulse_len = pulse_lengths[i];
        if (i & 1) // odd (positive pulses)
        {
            if (pulse_len < thresh[0]) // short
            {
                pos_len_tot[0] = pos_len_tot[0] + pulse_len;
                pos_len_count[0]++;
                if (pulse_len < pos_min_len[0])
                {
                    pos_min_len[0] = pulse_len;
                }
                if (pulse_len > pos_max_len[0])
                {
                    pos_max_len[0] = pulse_len;
                }
            }
            else if (pulse_len > thresh[1]) // long
            {
                pos_len_tot[2] = pos_len_tot[2] + pulse_len;
                pos_len_count[2]++;
                if (pulse_len < pos_min_len[2])
                {
                    pos_min_len[2] = pulse_len;
                }
                if (pulse_len > pos_max_len[2])
                {
                    pos_max_len[2] = pulse_len;
                }
            }
            else // medium
            {
                pos_len_tot[1] = pos_len_tot[1] + pulse_len;
                pos_len_count[1]++;
                if (pulse_len < pos_min_len[1])
                {
                    pos_min_len[1] = pulse_len;
                }
                if (pulse_len > pos_max_len[1])
                {
                    pos_max_len[1] = pulse_len;
                }
            }
        }
        else // even (negative pulses)
        {
            if (pulse_len < thresh[0]) // short
            {
                neg_len_tot[0] = neg_len_tot[0] + pulse_len;
                neg_len_count[0]++;
                if (pulse_len < neg_min_len[0])
                {
                    neg_min_len[0] = pulse_len;
                }
                if (pulse_len > neg_max_len[0])
                {
                    neg_max_len[0] = pulse_len;
                }
            }
            else if (pulse_len > thresh[1]) // long
            {
                neg_len_tot[2] = neg_len_tot[2] + pulse_len;
                neg_len_count[2]++;
                if (pulse_len < neg_min_len[2])
                {
                    neg_min_len[2] = pulse_len;
                }
                if (pulse_len > neg_max_len[2])
                {
                    neg_max_len[2] = pulse_len;
                }
            }
            else // medium
            {
                neg_len_tot[1] = neg_len_tot[1] + pulse_len;
                neg_len_count[1]++;
                if (pulse_len < neg_min_len[1])
                {
                    neg_min_len[1] = pulse_len;
                }
                if (pulse_len > neg_max_len[1])
                {
                    neg_max_len[1] = pulse_len;
                }
            }
        }
    }
    
    float pos_min_len_ns[3];
    float pos_max_len_ns[3];
    float pos_len_avg_flt_ns[3];
    
    float neg_min_len_ns[3];
    float neg_max_len_ns[3];
    float neg_len_avg_flt_ns[3];

    for(int i=0; i<3; i++)
    {
        pos_min_len_ns[i] = pos_min_len[i] * sample_time_ns;
        pos_max_len_ns[i] = pos_max_len[i] * sample_time_ns;
        neg_min_len_ns[i] = neg_min_len[i] * sample_time_ns;
        neg_max_len_ns[i] = neg_max_len[i] * sample_time_ns;
        pos_len_avg_flt_ns[i] = ((float)pos_len_tot[i]/(float)pos_len_count[i]) * sample_time_ns;
        neg_len_avg_flt_ns[i] = ((float)neg_len_tot[i]/(float)neg_len_count[i]) * sample_time_ns;
    }
    
    printf("Analysing duty-cycle distortion ... \n");
    printf("Found %4d short positive pulses.  pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", pos_len_count[0], pos_min_len_ns[0], pos_max_len_ns[0], pos_len_avg_flt_ns[0], (pos_max_len_ns[0]-pos_min_len_ns[0]) );
    printf("Found %4d short negative pulses.  pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", neg_len_count[0], neg_min_len_ns[0], neg_max_len_ns[0], neg_len_avg_flt_ns[0], (neg_max_len_ns[0]-neg_min_len_ns[0]) );
    printf("Found %4d medium positive pulses. pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", pos_len_count[1], pos_min_len_ns[1], pos_max_len_ns[1], pos_len_avg_flt_ns[1], (pos_max_len_ns[1]-pos_min_len_ns[1]) );
    printf("Found %4d medium negative pulses. pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", neg_len_count[1], neg_min_len_ns[1], neg_max_len_ns[1], neg_len_avg_flt_ns[1], (neg_max_len_ns[1]-neg_min_len_ns[1]) );  
    printf("Found %4d long positive pulses.   pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", pos_len_count[2], pos_min_len_ns[2], pos_max_len_ns[2], pos_len_avg_flt_ns[2], (pos_max_len_ns[2]-pos_min_len_ns[2]) );
    printf("Found %4d long negative pulses.   pulse_length(ns): min %6.2f, max %6.2f, avg %6.2f, pk-pk jitter %5.2f\n", neg_len_count[2], neg_min_len_ns[2], neg_max_len_ns[2], neg_len_avg_flt_ns[2], (neg_max_len_ns[2]-neg_min_len_ns[2]) );
    
    float pos_duty_cycle[3];
    
    for(int i=0; i<3; i++)
    {
        pos_duty_cycle[i] = (pos_len_avg_flt_ns[i]/(pos_len_avg_flt_ns[i] + neg_len_avg_flt_ns[i]))*100;
    }
    
    printf("Short pulse duty cycle  = %.3f%%, pulse_width difference = %.2fns\n", pos_duty_cycle[0], (pos_len_avg_flt_ns[0] - neg_len_avg_flt_ns[0]) );
    printf("Medium pulse duty cycle = %.3f%%, pulse_width difference = %.2fns\n", pos_duty_cycle[1], (pos_len_avg_flt_ns[1] - neg_len_avg_flt_ns[1]) );
    printf("Long pulse duty cycle   = %.3f%%, pulse_width difference = %.2fns\n", pos_duty_cycle[2], (pos_len_avg_flt_ns[2] - neg_len_avg_flt_ns[2]) );
    
    // So actually duty cycle distortion isn't the whole problem.
    // Intersymbol interference is also a problem.
    // This results in the first short pulse after a medium being shorter than it should be.
    // You can see this best in the preamble where you can see the delay for an edge after one, two or three UI.
    // So you will typically get a medium then a short short and a long short.
    // So to measure this we'll have to track if each short is the first or second of two shorts (two shorts almost always appear together). exception is in preamble.
    
    unsigned short_tot[3] = {0}; // short after pulse length 1, 2 and 3UI totals
    unsigned short_count[3] = {0}; // short count after pulse length 1, 2 and 3UI
    unsigned short_min_len[3] = {1000,1000,1000};  
    unsigned short_max_len[3] = {0};
    
    for(int i=i_start; i<i_end; i++)
    {
        unsigned pulse_len = pulse_lengths[i];
        if (pulse_len < thresh[0]) // short
        {
            unsigned prev_pulse = pulse_lengths[i-1];
            if (prev_pulse < thresh[0]) // short 1UI
            {
                short_tot[0] = short_tot[0] + pulse_len;
                short_count[0]++;
                if (pulse_len < short_min_len[0])
                {
                    short_min_len[0] = pulse_len;
                }
                if (pulse_len > short_max_len[0])
                {
                    short_max_len[0] = pulse_len;
                }
            }
            else if (prev_pulse > thresh[1]) // long 3UI
            {
                short_tot[2] = short_tot[2] + pulse_len;
                short_count[2]++;
                if (pulse_len < short_min_len[2])
                {
                    short_min_len[2] = pulse_len;
                }
                if (pulse_len > short_max_len[2])
                {
                    short_max_len[2] = pulse_len;
                }
            }
            else
            {
                short_tot[1] = short_tot[1] + pulse_len;
                short_count[1]++;
                if (pulse_len < short_min_len[1])
                {
                    short_min_len[1] = pulse_len;
                }
                if (pulse_len > short_max_len[1])
                {
                    short_max_len[1] = pulse_len;
                }
            }
        }
    }
    
    float short_min_len_ns[3];
    float short_max_len_ns[3];
    float short_len_avg_flt_ns[3];
    
    for(int i=0; i<3; i++)
    { 
        short_min_len_ns[i] = short_min_len[i] * sample_time_ns;
        short_max_len_ns[i] = short_max_len[i] * sample_time_ns;
        short_len_avg_flt_ns[i] = ((float)short_tot[i]/(float)short_count[i]) * sample_time_ns;
    }
    
    printf("Analysing inter symbol interference ...\n");
    printf("Found %4d short pulses after a short pulse.  pulse_length(ns): min %.2f, max %.2f, avg %.2f, jitter %.2f\n", short_count[0], short_min_len_ns[0], short_max_len_ns[0], short_len_avg_flt_ns[0], (short_max_len_ns[0]-short_min_len_ns[0]) );
    printf("Found %4d short pulses after a medium pulse. pulse_length(ns): min %.2f, max %.2f, avg %.2f, jitter %.2f\n", short_count[1], short_min_len_ns[1], short_max_len_ns[1], short_len_avg_flt_ns[1], (short_max_len_ns[1]-short_min_len_ns[1]) );    
    printf("Found %4d short pulses after a long pulse.   pulse_length(ns): min %.2f, max %.2f, avg %.2f, jitter %.2f\n", short_count[2], short_min_len_ns[2], short_max_len_ns[2], short_len_avg_flt_ns[2], (short_max_len_ns[2]-short_min_len_ns[2]) );
    
    // Also, we can write something to calculate the jitter in zero crossings.
    // Say take the 100 full frames block with the start and end time. Then we know each UI should be at (end-start)/number of UI. number of UI is 100*2*64 = 12800.
    // We have a float to record the average UI for this block.
    // We can then compare actual pulse times with where they should have been.

    unsigned edge_time = 0;
    unsigned pulse_len_quant;
    float ideal_edge_time;
    unsigned ideal_edge_time_int = 0;
    float edge_tie[4*SAMPLES] = {0};
    float min_tie = 0;
    float max_tie = 0;
    
    unsigned sample_time_ns_int = 4;

    printf("Analysing time interval error of zero crossings.\n");
    for(int i=i_start; i<(i_start+500); i++)
    {
        unsigned pulse_len = pulse_lengths[i];
        //edge_time = edge_time + (float) (pulse_len * sample_time_ns);
        edge_time += pulse_len;
        
        if (pulse_len < thresh[0]) // short 1UI
        {
            pulse_len_quant = 1;
        }
        else if (pulse_len > thresh[1]) // long 3UI
        {
            pulse_len_quant = 3;
        }
        else
        {
            pulse_len_quant = 2;
        }
        ideal_edge_time_int = ideal_edge_time_int + pulse_len_quant;
        ideal_edge_time = (ideal_edge_time_int * time_1ui_fl);
        edge_tie[i] = (float)(edge_time * sample_time_ns_int) - ideal_edge_time;
        if (edge_tie[i] > max_tie)
        {
            max_tie = edge_tie[i];
            //printf("edge_tie %5.2f, min %5.2f, max %5.2f, i %d\n", edge_tie[i], min_tie, max_tie, i);
            //printf("ideal_edge_time %f, edge_time %d\n", ideal_edge_time, (edge_time * sample_time_ns_int));
        }
        if (edge_tie[i] < min_tie)
        {
            min_tie = edge_tie[i];
            //printf("edge_tie %5.2f, min %5.2f, max %5.2f, i %d\n", edge_tie[i], min_tie, max_tie, i);
            //printf("ideal_edge_time %f, edge_time %d\n", ideal_edge_time, (edge_time * sample_time_ns_int));
        }
        unsigned edge_time_ns = edge_time * sample_time_ns_int;
        //printf("i %3d, pulse_len %3d, edge_time %3d, edge_time_ns %5d, len_quant %d, ideal_edge_time %f, edge_tie %5.2f, min %5.2f, max %5.2f\n", i, pulse_len, edge_time, edge_time_ns, pulse_len_quant, ideal_edge_time, edge_tie[i], min_tie, max_tie);
    }
    printf("Zero crossing TIE (ns): min %.2f, max %.2f, pk-pk %.2f\n", min_tie, max_tie, (max_tie - min_tie));
    
    //while(1);
    for(unsigned i = 0; i < SAMPLES; i++)
    {
        printf("%u\n",samples[i]);
    }

}

int main(void) {
    par
    {
        on tile[TILE]:
        {
            #ifndef XC200
            board_setup();
            #endif
            spdif_rx_analyse();
        }
    }
    return 0;
}
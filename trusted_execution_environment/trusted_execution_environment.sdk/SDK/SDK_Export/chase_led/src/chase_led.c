/*
 * chase_led.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "leds.h"
#include "trusted_key.h"

extern XGpio Gpio;

/**
 * Attempts to add a gate permission to a (presumably) closed
 *   list, and then prints all the permissions to standard output
 */
void callback()
{
    u32 i = 0;
    static char *buffer = "reg 00 contents: 0x00000000rn";
    static u32 len = 31;

    for(i = 0; i < 32; i++)
    {
    	add_gate_permission(TRUSTED_KEY_PERM_IO_O, 0xFEDCBA98);
        snprintf (
                buffer, len, "reg %02d contents: 0x%08X\r\n",
                (unsigned) i, (unsigned) read_gate_permission(i)
                );
        print(buffer);
    }
}

/**
 * Simple initialization routine
 *
 * @return a value other than XST_SUCCESS if something goes wrong
 */
Xuint32 initialize()
{
    init_platform();
    init_trusted_key();
    init_trusted_gate();
    return init_leds();
}

/**
 * Main testing routine
 */
int main()
{
	int i;

	/* init */
    if (initialize() != XST_SUCCESS)
    {
        return XST_FAILURE;
    }

    /* give every key up to but not including the HCE key the I/O
      output permission */
    for(i = 0; i < TRUSTED_KEY_ID_HCE; i++)
    {
    	add_gate_permission(TRUSTED_KEY_ID_MEM_R, i);
        add_trusted_key(i, i);
    }

    /* the first read seals the gate */
    read_gate_key(3);

    /* none of these should get any permissions */
    for (i = TRUSTED_KEY_ID_HCE; i <= TRUSTED_KEY_ID_IRQM; i++)
    {
        add_gate_permission(TRUSTED_KEY_PERM_IO_O, i);
        add_trusted_key(i, i);
    }

    /* this key got the I/O output permission */
    use_trusted_key(TRUSTED_KEY_ID_SIF);

    /* this one didn't */
    /* use_trusted_key(TRUSTED_KEY_ID_HCE); */

    /* each cycle_leds call runs a single frame, delays, and calls
      the callback function */
    while(! cycle_leds(100000, callback));

    return 0;
}

/**
 * @file hello_world.c
 * @description Takes no prisoners and no shit from anyone.
 *              Does however take your mom.
 */

#include <stdio.h>
#include "platform.h"
#include "pl_dev_driver.h"

int main()
{
    char *outmesg =
            "this hello world was brought to you by the number "
            "0x00000000rn";
    unsigned len = strlen(outmesg);

    PL_DEV_mReset(XPAR_SIMPLE_PROCESSOR_WRAPPER_0_BASEADDR);
    PL_DEV_mWriteReg (
            XPAR_SIMPLE_PROCESSOR_WRAPPER_0_BASEADDR, 4, 0xFEDCBA98
            );
    snprintf (
            outmesg, len,
            "this hello world was brought to you by the number "
            "0x%08x\r\n",
            (unsigned) PL_DEV_mReadReg (
                    XPAR_SIMPLE_PROCESSOR_WRAPPER_0_BASEADDR, 4
                    )
            );
    init_platform();

    print(outmesg);

    return 0;
}

/**
 * @file hello_world.c
 * @description 
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

    PL_DEV_mReset(XPAR_EDKREGFILE_0_BASEADDR);
    PL_DEV_mWriteReg(XPAR_EDKREGFILE_0_BASEADDR, 4, 0x0000000D);
    PL_DEV_mWriteReg(XPAR_EDKREGFILE_0_BASEADDR, 1, 0x0000000D);
    PL_DEV_mWriteReg(XPAR_EDKREGFILE_0_BASEADDR, 2, 0x0000000A);
    PL_DEV_mWriteReg(XPAR_EDKREGFILE_0_BASEADDR, 3, 0x0000000D);
    snprintf (
    		outmesg, len,
    		"this hello world was brought to you by the number "
    		"0x%08x\r\n",
    		(unsigned) PL_DEV_mReadReg(XPAR_EDKREGFILE_0_BASEADDR, 3)
    		);
    init_platform();
    print(outmesg);

    return 0;
}

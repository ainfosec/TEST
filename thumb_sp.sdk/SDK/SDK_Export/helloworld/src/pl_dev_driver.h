/*****************************************************************************
* Filename:          C:\Users\sean\Work\trusted_execution_environment\trusted_execution_environment.sdk/SDK/SDK_Export/chase_led/src/pl_dev_driver.h
* Version:           1.00.a
* Description:       Device driver for access to devices in programmable logic
* Date:              Fri, Oct 11, 2013  4:18:39 PM
*****************************************************************************/

#ifndef PL_DEV_DRIVER_H
#define PL_DEV_DRIVER_H

#include "xbasic_types.h"
#include "xstatus.h"
#include "xil_io.h"
#include "xparameters.h"

/** Interrupt ReQuest codes */
typedef enum _PL_DEV_IRQS
{
  PL_DEV_IRQ_ECC_UE = 90,
  PL_DEV_IRQ_ECC_INTERRUPT
} PL_DEV_IRQS;

/** Software Reset Space Register Offsets */
#define PL_DEV_SOFT_RST_SPACE_OFFSET (0x00000100)

/** Software Reset Masks */
#define PL_DEV_SOFT_RESET (0x0000000A)

/**
 * Write a value to a peripheral register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddr base memory address of the desired peripheral
 * @param   Reg in-peripheral register to write to
 * @param   Data data to write to the register
 * @return  None.
 */
#define PL_DEV_mWriteReg(BaseAddr, Reg, Data) \
  Xil_Out32( (BaseAddr) + (4 * Reg), (Xuint32) (Data) )

/**
 *
 * Read a value from a peripheral register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddr base memory address of the desired peripheral
 * @param   Reg in-peripheral register to read from
 * @return  Data read from the register
 */
#define PL_DEV_mReadReg(BaseAddr, Reg) \
  Xil_In32( (BaseAddr) + (4 * Reg) )

/**
 * Reset a peripheral via software.
 *
 * @param   BaseAddr base memory address of the desired peripheral
 * @return  None
 */
#define PL_DEV_mReset(BaseAddr) \
  Xil_Out32( (BaseAddr) + PL_DEV_SOFT_RST_SPACE_OFFSET, PL_DEV_SOFT_RESET )

#endif /** PL_DEV_DRIVER_H */

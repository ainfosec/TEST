/**
 * @file trusted_key.h
 *
 * Driver for a trusted_key peripheral. A trusted_key is
 *   designed to drive a trusted_gate, storing 28 special
 *   purpose keys which can be swapped in under different
 *   circumstances, making it easier to implement specifications
 *   such as ARM TrustZone(r).
 *
 * Copyright (c) 2013 Assured Information Security
 *   All rights reserved.
 *
 * @author Sean McClain <mcclains@ainfosec.com>
 * @version 1.00
 */

#include "pl_dev_driver.h"

#ifndef TRUSTED_KEY_H
#define TRUSTED_KEY_H

/** Default TrustZone signals: send 010 for both AxPROT */
#define TRUSTED_KEY_TZ 0x00000007

/** The "normal world" unprivileged key */
#define TRUSTED_KEY_NS 0x03

/**
 * The trusted gate peripheral can control several different signals.
 *   Each of these signals is labeled here.
 *
 * Note: the current version of the trusted_gate peripheral
 *   only has a 5 bit permission space.
 *   Therefore, bits have been grouped to fit this address space.
 *   The trusted_gate peripheral is extensible and future versions
 *   will be able to differentiate between each signal.
 */
typedef enum _TRUSTED_KEY_PERM
{
    TRUSTED_KEY_PERM_IRQ     = 0x00000001, /** interrupt request  */
    TRUSTED_KEY_PERM_FIQ     = 0x00000001, /** fast IRQ           */
    TRUSTED_KEY_PERM_TRAP    = 0x00000001, /** top priority IRQ   */
    TRUSTED_KEY_PERM_USER_AW = 0x00000002, /** user write address */
    TRUSTED_KEY_PERM_USER_RW = 0x00000002, /** user read address  */
    TRUSTED_KEY_PERM_USER_W  = 0x00000002, /** user write data    */
    TRUSTED_KEY_PERM_USER_R  = 0x00000002, /** user read data     */
    TRUSTED_KEY_PERM_USER_B  = 0x00000002, /** user response      */
    TRUSTED_KEY_PERM_MEM_R   = 0x00000004, /** BRAM read enable   */
    TRUSTED_KEY_PERM_MEM_W   = 0x00000004, /** BRAM write enable  */
    TRUSTED_KEY_PERM_IO_I    = 0x00000008, /** input I/O          */
    TRUSTED_KEY_PERM_IO_O    = 0x00000008, /** output I/O         */
    TRUSTED_KEY_PERM_IO_T    = 0x00000008, /** tri-state I/O      */
    TRUSTED_KEY_PERM_SMP_AMP = 0x00000010  /** switch SMP/AMP     */
} TRUSTED_KEY_PERM;

/**
 * Labels for each register matching their intended purpose,
 *   designed to be used as the arguments to functions such as
 *   use_trusted_key.
 *
 * As an example, use_trusted_key(TRUSTED_KEY_ID_GPIO_O) would
 *   unlock the TRUSTED_KEY_PERM_IO in the associated gate.
 *
 * The first 12 labels correspond directly to control permissions
 *   in the trusted_gate peripheral.
 *
 * The remaining labels modify the "normal world" key.
 */
typedef enum _TRUSTED_KEY_MAP
{
    TRUSTED_KEY_ID_CRIT = 0x00, /** crit. section for SMP */
    TRUSTED_KEY_ID_GPIO_I,      /** input I/O channel     */
    TRUSTED_KEY_ID_GPIO_O,      /** output I/O channel    */
    TRUSTED_KEY_ID_GPIO_T,      /** tri-state I/O channel */
    TRUSTED_KEY_ID_MEM_R,       /** BRAM read enable      */
    TRUSTED_KEY_ID_MEM_W,       /** BRAM write enable     */
    TRUSTED_KEY_ID_AWUSER,      /** user write address    */
    TRUSTED_KEY_ID_ARUSER,      /** user read address     */
    TRUSTED_KEY_ID_WUSER,       /** user write data       */
    TRUSTED_KEY_ID_RUSER,       /** user read data        */
    TRUSTED_KEY_ID_BUSER,       /** user response         */
    TRUSTED_KEY_ID_IRQ,         /** interrupt request     */

    /**
     * TrustZone meaning: Whether AMP (asymmetric) or
     *   SMP (symmetric multi-processing) can be set from
     *   normal world.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_SMP_AMP permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_NS_SMP,

    /**
     * TrustZone meaning: If a page table entry in a TLB
     *   (translation look-aside buffer) is lockable, determine if
     *   it can be locked in non-secure state.
     *   Each TL bit is associated with one TLB entry.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_MEM_R permission to
     *   the normal world key.
     */
    TRUSTED_KEY_ID_TL,

    /**
     * TrustZone meaning: Whether to allow non-secure access to
     *   pre-load memory.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_MEM_W permission to
     *   the normal world key. It is recommended that you seal
     *   the trusted_gate access control table when you modify this
     *   permission to simulate TrustZone functionality most
     *   accurately.
     */
    TRUSTED_KEY_ID_PLE,

    /**
     * TrustZone meaning: Whether to enable non-secure access to
     *   SIMD (single instruction, multiple data) extensions.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_USER_B permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_NSASEDIS,

    /**
     * TrustZone meaning: Whether to enable non-secure access to
     *   the non-system bits in the register file.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_USER_W permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_NSD32DIS,

    /**
     * TrustZone meaning: Whether to allow access to
     *   non-invasive debug devices for non-secure users.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_USER_R permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_SUNIDEN,

    /**
     * TrustZone meaning: Whether to allow access to invasive debug
     *   devices for non-secure users.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_USER_AR permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_SUIDEN,

    /**
     * TrustZone meaning: Whether to allow any access to non-secure
     *   IMEM (instruction memory).
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_USER_AW permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_SIF,

    /**
     * TrustZone meaning: Whether the HVC (hypervisor call)
     *   instruction is a recognized part of the ARM ISA
     *   (instruction set architecture) in normal world.
     *   If this bit is low, the instruction is simply not
     *   included in the instruction set in normal world.
     *
     * Local meaning: none.
     *   It is recommended that you modify the state of an
     *   interrupt named HVC when you modify this bit.
     */
    TRUSTED_KEY_ID_HCE,

    /**
     * TrustZone meaning: whether the SMC (secure monitor call)
     *   instruction is a recognized part of the ARM ISA
     *   (instruction set architecture) in normal world.
     *   If this bit is low, the instruction is simply not
     *   included in the instruction set in normal world.
     *   The SMC call typically calls a user defined interrupt,
     *   and is the preferred way of flipping the NS bit.
     *
     * Local meaning: none.
     *   It is recommended that you modify the state of an
     *   interrupt named SMC when you modify this bit.
     */
    TRUSTED_KEY_ID_SCD,

    /**
     * TrustZone meaning: Whether the A (abort pending) flag is
     *   writable from non-secure world.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_IO_I permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_AW,

    /**
     * TrustZone meaning: Whether the F
     *   (FIQ (fast interrupt request) pending) flag is writable
     *   from non-secure world.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_IO_O permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_FW,

    /**
     * TrustZone meaning: Whether the I
     *   (IRQ (interrupt request) pending) flag is writable
     *   from non-secure world.
     *   Not actually implemented in TrustZone, included for
     *   completeness and testing purposes.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_IO_T permission
     *   to the normal world key.
     */
    TRUSTED_KEY_ID_IW,

    /**
     * TrustZone meaning: Whether external aborts are taken in
     *   abort or monitor mode.
     *   Monitor mode means the affected core continues to run
     *   with limited debugging functionality enabled.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_TRAP permission to
     *   the normal world key.
     */
    TRUSTED_KEY_ID_EA,

    /**
     * TrustZone meaning: Whether FIQs are taken in abort or
     *   monitor mode.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_FIQ permission to
     *   the normal world key.
     */
    TRUSTED_KEY_ID_FIQM,

    /**
     * TrustZone meaning: Whether IRQs are taken in abort or
     *   monitor mode.
     *
     * Local meaning: Add the TRUSTED_KEY_PERM_IRQ permission to
     *   the normal world key.
     */
    TRUSTED_KEY_ID_IRQM
} TRUSTED_KEY_MAP;

/**
 * Select and send in a pre-defined key value to the trusted_gate
 *   peripheral.
 *
 * @param x a TRUSTED_KEY_MAP corresponding to the key to use
 */
#define use_trusted_key(x) PL_DEV_mWriteReg ( \
        XPAR_TRUSTED_KEY_0_BASEADDR, 0x00, \
        TRUSTED_KEY_TZ | (1 << ((x) + 4)) \
        )

/**
 * Select and send in the "normal world" key to the trusted_gate
 *   peripheral.
 *
 * You can modify the "normal world" key by modifying some of
 *   the TRUSTED_KEY_MAP values.
 */
#define use_trusted_normal_key() PL_DEV_mWriteReg ( \
        XPAR_TRUSTED_KEY_0_BASEADDR, 0x00, \
        TRUSTED_KEY_TZ | (1 << TRUSTED_KEY_NS) \
        )

/**
 * Define a trusted key value.
 *
 * The trusted_gate peripheral contains a table matching
 *   key values to permissions.
 *
 * An example: calling
 *
 *   TRUSTED_KEY_MAP key = TRUSTED_KEY_ID_GPIO_O;
 *   unsigned value = 0xDEADBEEF;
 *   unsigned permissions = 1 << TRUSTED_KEY_PERM_IO_I;
 *   permissions |= 1 << TRUSTED_KEY_PERM_IO_O;
 *   permissions |= 1 << TRUSTED_KEY_PERM_IO_T;
 *
 *   add_trusted_key(key, value);
 *   add_gate_permissions(permissions, value);
 *   use_trusted_key(key);
 *
 * would unlock all three I/O channels.
 *
 * @param x a TRUSTED_KEY_MAP value matching this key's label.
 *          On the trusted_key side, this is how you will refer
 *          to the key.
 * @param y a unique value. This value should also be added
 *          to the trusted_gate peripheral along with its associated
 *          permissions. This is how the key is referred to by
 *          the trusted_gate.
 */
#define add_trusted_key(x, y) PL_DEV_mWriteReg ( \
        XPAR_TRUSTED_KEY_0_BASEADDR, ((x) + 4), (y) \
        )

/**
 * Returns the current unique value associated with a key located
 *   at the specified index.
 *
 * @param x a TRUSTED_KEY_MAP value, ideally matching this key's
 *          purpose, which is used to index this key.
 * @return the unique value within the trusted_key peripheral at
 *         the specified index
 */
#define read_trusted_key(x) \
		PL_DEV_mReadReg(XPAR_TRUSTED_KEY_0_BASEADDR, (x))

/**
 * Sets the trusted_key peripheral's reset switch, initializing it
 */
#define init_trusted_key() PL_DEV_mReset(XPAR_TRUSTED_KEY_0_BASEADDR)



/**
 * Sets the trusted_gate's reset bit, initializing it.
 * This destroys all data in the access control table and returns
 *   it to the writable state.
 */
#define init_trusted_gate() \
        PL_DEV_mReset(XPAR_TRUSTED_GATE_0_BASEADDR)

/**
 * Adds an entry to the access control table inside the
 *   trusted_gate peripheral.
 *
 * @param x permissions to add. Each permission can be derived
 *          as in the following example:
 *
 * TRUSTED_KEY_PERM allow_IO_out = (1 << TRUSTED_KEY_PERM_IO_O);
 *
 *          Multiple permissions can be OR'ed together.
 *
 * @param y a unique value, which matches a value in the
 *          trusted_key peripheral.
 * @see add_trusted_key
 */
#define add_gate_permission(x, y) \
        PL_DEV_mWriteReg(XPAR_TRUSTED_GATE_0_BASEADDR, (x), (y))

/**
 * Returns a key value from the access control table from the
 *   specified index.
 *
 * @param x an index of an entry within the access control table
 * @return the indexed key value
 */
#define read_gate_key(x) \
		PL_DEV_mReadReg(XPAR_TRUSTED_GATE_0_BASEADDR, (x))
/**
 * Returns the permissions of the key in the access control table
 *   at the specified index.
 *
 * @param x an index of an entry within the access control table
 * @return the permissions associated with the indexed key value
 */
#define read_gate_permission(x) \
		PL_DEV_mReadReg(XPAR_GATE_VIEWER_0_BASEADDR, (x))

#endif /* TRUSTED_KEY_H */

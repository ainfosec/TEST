/**
 * @file leds.h
 * Driver for the 8-bit LEDS on the ZedBoard, including
 *   support for back-and-forth scanning.
 *
 * Copyright (c) 2013 Assured Information Security
 *   All rights reserved.
 *
 * @author Sean McClain <mcclains@ainfosec.com>
 * @version 1.00
 */
#include "xgpio.h"
#include "pl_dev_driver.h"

#ifndef LEDS_H
#define LEDS_H

/** GPIO channel reserved for LEDs */
#define LED_CHANNEL 1

/** Fine tuning to keep LED_DELAY in microseconds*/
#define CYCLE_RATE 76

/** Initialization routine */
#define init_leds() XGpio_Initialize(&Gpio, XPAR_LEDS_8BITS_DEVICE_ID)

/**
 * Helper for wait functions that wait a number of microseconds
 *
 * @param x number of microseconds to wait
 * @return an integer such that running a simple loop this
 *         many iterations will result in a delay of 1 microsecond
 */
#define LED_DELAY(x) (x * CYCLE_RATE)

/**
 * Defines states and transfers for an 8-bit LED scanner.
 *
 * Directions assume the ZedBoard is oriented so that the
 *   DIGILENT logo is right-side up.
 **/
typedef enum _LED_DIR
{
    LED_DIR_LEFT,                /** Scanning right-to-left */
    LED_DIR_RIGHT,               /** Scanning left-to-right */
    LED_WALL_RIGHT = 0x00000001, /** Rightmost value */
    LED_WALL_LEFT = 0x00000080,  /** Leftmost value */
    LED_DIR_INC = 0x00000001     /** Bits to shift per tick */
} LED_DIR;

/**
 * Meant to be called in a loop, move the active LED 1 position
 *   in the direction it is currently scanning in until a wall
 *   is hit, then wait a specified amount of time. When a wall
 *   is hit, the direction is automatically reversed.
 *
 * @param wait_us number of microseconds to wait
 * @param callback a callback that can be triggered whenever a
 *        wall is hit
 * @return zero, or a non-zero error code if there are problems
 */
int cycle_leds(int wait_us, void (*callback)());

#endif /* LEDS_H */

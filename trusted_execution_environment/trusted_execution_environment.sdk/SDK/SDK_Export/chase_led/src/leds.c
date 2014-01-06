#include "leds.h"

XGpio Gpio;

/// scan back and forth, with a callback on wall hits
int cycle_leds(int wait_us, void (*callback)())
{
	u32 i = 0;
    static LED_DIR dir = LED_DIR_LEFT, pattern = LED_WALL_RIGHT;

    /* The 8 LEDS represent an 8 bit integer */
    XGpio_DiscreteWrite(&Gpio, (unsigned) LED_CHANNEL, pattern);

    /* Continue until hitting a wall, then reverse */
    pattern = dir == LED_DIR_LEFT
            ? pattern << LED_DIR_INC
            : pattern >> LED_DIR_INC;
    dir = pattern >= LED_WALL_LEFT
        ? LED_DIR_RIGHT
        : pattern <= LED_WALL_RIGHT
        ? LED_DIR_LEFT
        : dir;

    /* optional callback on wall hits */
    if (LED_WALL_LEFT <= pattern || pattern <= LED_WALL_RIGHT)
    {
        if (callback)
        {
            callback();
        }
    }

    /* wait a specified number of microseconds before returning */
    while (++i < LED_DELAY(wait_us));
    return 0;
}

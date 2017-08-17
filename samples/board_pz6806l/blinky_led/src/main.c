/*
 * Copyright (c) 2016 Intel Corporation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <zephyr.h>
#include <board.h>
#include <device.h>
#include <gpio.h>

/* 1000 msec = 1 sec */
#define SLEEP_TIME 1000

void main(void)
{
	int cnt = 0;
	struct device *dev;

	dev = device_get_binding(BOARD_LED1_PORT);
	if (dev != NULL) {
		/* Set LED1 pin as output */
		gpio_pin_configure(dev, BOARD_LED1_PIN, GPIO_DIR_OUT);
	} else {
		return;
	}

	while (1) {
		/* Set pin to HIGH/LOW every 1 second */
		gpio_pin_write(dev, BOARD_LED1_PIN, cnt % 2);
		cnt++;
		k_sleep(SLEEP_TIME);
	}
}

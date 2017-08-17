.. _blinky-sample:

Blinky Application
##################

Overview
********

The Blinky example shows how to configure GPIO pins as outputs which can also be
used to drive LEDs on the hardware usually delivered as "User LEDs" on STM32 PZ6806L
boards in Zephyr.

Requirements
************

The demo assumes that an LED is connected to one of GPIO lines. The
sample code is configured to work on boards with user defined buttons and that
have defined the BOARD_LED1\_* variables in :file:`board.h`.

Building
********************

This samples does not output anything to the console.  It can be built as follows:

.. code-block:: console

   $ make

After flashing the image to the board, the user LED on the board should start to
blink.

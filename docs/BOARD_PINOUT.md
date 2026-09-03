# V0.1 teaching-board pinout

The V0.1 board intentionally keeps the first hardware contract small and fixed. Other STM32F103C8T6 GPIOs are not connected to virtual peripherals yet and remain available for later expansion.

| Virtual peripheral | STM32 pin | Active level / bus |
|---|---|---|
| LED0 | PC13 | LOW = ON |
| LED1 | PA0 | HIGH = ON |
| LED2 | PA1 | HIGH = ON |
| LED3 | PA2 | HIGH = ON |
| KEY0 | PB12 | LOW while pressed |
| KEY1 | PB13 | LOW while pressed |
| KEY2 | PB14 | LOW while pressed |
| KEY3 | PB15 | LOW while pressed |
| SSD1306 SCL | PB6 | I2C1 SCL |
| SSD1306 SDA | PB7 | I2C1 SDA |
| SSD1306 address | — | 7-bit 0x3C |

## Why fixed wiring first?

A fixed teaching board makes the first milestone deterministic: the same HAL project always maps to the same visible hardware. A future version can add a configurable pin-routing layer without changing the firmware loader, Renode process manager, or SDL component architecture.

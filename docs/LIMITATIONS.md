# V0.1 limitations / validation checklist

## Known limitations

- 目标是 HAL 教学常见场景，不声称 STM32F103C8T6 全外设/全时序覆盖。
- 当前直接复用 Renode 的 `platforms/cpus/stm32f103.repl`；它的 memory map 是通用模型，V0.1 没有额外强制 C8T6 的 64KB Flash / 20KB SRAM 越界检查。
- GPIO LED 状态通过 Renode Monitor 查询，刷新周期约 80ms；不适合把它当逻辑分析仪。
- SSD1306 bridge 支持最常见的 0x00 Command / 0x40 Data 流、Page/Horizontal addressing、Column/Page address 等；冷门滚动命令仅被忽略。
- OLED 只支持 128x64、I2C1、0x3C。
- 软件 bit-bang I2C 暂不支持；V0.1 使用 Renode I2C1 peripheral。
- 如果用户在 `SystemClock_Config()` 中依赖 Renode 未实现的 RCC 细节，固件可能停在 HAL timeout/ready loop，需要后续补 platform model。

## First firmware validation order

1. `HAL_Init()` + `HAL_Delay(500)`
2. PC13 Toggle
3. PA0/1/2 Toggle
4. PB12~15 polling
5. PB12 EXTI interrupt
6. I2C1 `HAL_I2C_IsDeviceReady(0x3C<<1)`
7. SSD1306 init
8. Full 1024-byte display update
9. OLED + button + LED combined demo

## If firmware does not start

Open Renode manually with the generated runtime script in `%TEMP%\VirtualSTM32\runtime.resc`, remove `--hide-log`, then inspect unimplemented register warnings. This will tell us exactly which STM32F103 peripheral model needs extending next.

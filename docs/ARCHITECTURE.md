# Architecture

```text
CubeIDE / Keil5
     |
     | build -> .elf / .axf
     v
 tools/ide_launch.cmd
     |
     v
VirtualSTM32.exe (SDL2)
     |                    ^
     | Monitor TCP        | %TEMP%/VirtualSTM32/oled.bin
     v                    |
Renode -------------------+
  Cortex-M3 / NVIC / SysTick
  STM32F1 GPIOA/B/C
  STM32F1 I2C1
  |
  +-- LED0..3 (GPIO output observers)
  +-- KEY0..3 (Renode Button -> GPIO input)
  +-- DummyI2CSlave 0x3C
          |
          +-- ssd1306_bridge.py -> 1024-byte framebuffer
```

## Why this split

NVBoard 的价值在“可视化外设 + 信号连接”，而 STM32 固件还需要 CPU/寄存器/中断/定时器模型。Renode 负责 MCU 仿真，VirtualSTM32 只负责用户能看到和点击的“桌面开发板”。

## Extension points

以后增加：

- UART：Renode socket terminal + GUI terminal component
- SPI TFT：SPI peripheral model + framebuffer
- ADC：slider/knob -> virtual analog value
- PWM：GPIO/timer observer -> LED brightness/servo angle
- EXTI：现有 Button/GPIO 链路可继续使用
- GDB：将 Renode GDB server 包装成 IDE Debug Launch 或 GUI Debug panel
- board.json：把当前 `BoardConfig.h` 改为运行时板卡描述，实现多个教学板 profile

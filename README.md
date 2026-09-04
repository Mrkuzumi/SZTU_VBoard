# SZTU_VBoard

SZTU_VBoard 是一个基于 **Renode + SDL2** 的 Windows 虚拟 STM32F103C8T6 开发板。

它可以直接运行 STM32 工程生成的 `.elf` / `.axf` 固件，并在虚拟开发板界面中显示 GPIO、按键和 SSD1306 OLED 的实际运行结果。

> 适合 STM32 HAL 学习、基础外设实验和无实物开发板时的程序验证。

---

## 功能

目前支持：

- STM32F103C8T6
- GPIO 输出
- GPIO 输入
- 4 个虚拟 LED
- 4 个虚拟按键
- I2C1
- SSD1306 128×64 OLED
- STM32 HAL GPIO
- STM32 HAL I2C 轮询方式
- GDB Server
- 自动清理 Renode 后台进程
- 重复启动时自动关闭旧虚拟板实例

### 板载资源

| 外设 | STM32 引脚 | 说明 |
|---|---|---|
| LED0 | PC13 | HIGH = 亮 |
| LED1 | PA0 | HIGH = 亮 |
| LED2 | PA1 | HIGH = 亮 |
| LED3 | PA2 | HIGH = 亮 |
| KEY0 | PB12 | LOW = 按下 |
| KEY1 | PB13 | LOW = 按下 |
| KEY2 | PB14 | LOW = 按下 |
| KEY3 | PB15 | LOW = 按下 |
| OLED SCL | PB6 | I2C1_SCL |
| OLED SDA | PB7 | I2C1_SDA |
| OLED 地址 | `0x3C` | SSD1306 |

---

# 快速开始

## 1. 克隆仓库

```powershell
git clone https://github.com/Mrkuzumi/SZTU_VBoard.git
cd SZTU_VBoard
```

## 2. 初始化运行环境

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup.ps1
```

首次运行会自动准备所需的 Renode 运行环境。

大型运行文件不会保存在 Git 仓库中，而是缓存在用户本地目录。

## 3. 编译 STM32 工程

使用 STM32CubeIDE 或 Keil 正常编译你的 STM32F103C8T6 工程。

支持：

```text
.elf
.axf
```

例如 CubeIDE 常见输出：

```text
Debug\
└─ project.elf
```

或：

```text
Release\
└─ project.elf
```

## 4. 启动虚拟开发板

```powershell
.\tools\run.ps1 "<firmware.elf>"
```

例如：

```powershell
.\tools\run.ps1 "...\MySTM32Project\Debug\MySTM32Project.elf"
```

虚拟开发板会自动启动并运行该固件。

---

# STM32CubeIDE 配置

SZTU_VBoard 不要求固定使用 Debug 或 Release。

只需要运行当前实际生成的 ELF 文件即可。

### GPIO 输出

例如使用 PC13 控制 LED0：

```c
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);
HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
```

### 按键输入

KEY0 对应 PB12，低电平按下。

CubeMX 推荐配置：

```text
PB12
GPIO_Input
Pull-up
```

读取：

```c
if (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_12) == GPIO_PIN_RESET)
{
    // KEY0 pressed
}
```

### SSD1306 OLED

CubeMX 配置：

```text
I2C1
PB6 = I2C1_SCL
PB7 = I2C1_SDA
```

推荐：

```text
100 kHz
7-bit address
```

HAL 中使用：

```c
#define SSD1306_ADDR (0x3C << 1)
```

当前已验证：

```c
HAL_I2C_IsDeviceReady()
HAL_I2C_Master_Transmit()
```

常见的 SSD1306 HAL 轮询式驱动可以直接使用。

---

# Keil

Keil 生成的 `.axf` 文件也可以直接运行：

```powershell
.\tools\run.ps1 "<firmware.axf>"
```

---

# 使用说明

虚拟板右上角 BACKEND 状态：

| 状态 | 含义 |
|---|---|
| 黄 | 后端正在启动 |
| 绿 | 后端已连接 |
| 红 | 后端启动失败 |

快捷键：

```text
R    重新加载固件
Esc  退出
```

关闭虚拟板后，SZTU_VBoard 会自动结束对应的 Renode 后台进程。

如果再次启动新的虚拟板，旧实例会自动退出。

---

# 项目结构

```text
SZTU_VBoard/
├─ assets/              # GUI 图片资源
├─ renode/              # Renode 辅助脚本
├─ src/
│  ├─ app/
│  ├─ backend/
│  ├─ board/
│  ├─ peripherals/
│  ├─ platform/
│  └─ ui/
├─ tools/
│  ├─ setup.ps1
│  ├─ setup_runtime.ps1
│  ├─ run.ps1
│  └─ build.ps1
├─ CMakeLists.txt
└─ README.md
```

---

# 开发 SZTU_VBoard

这一部分只针对需要修改 SZTU_VBoard 本身源码的开发者。

普通使用者不需要安装 Visual Studio 或 CMake。

### 开发环境

- Windows 10 / 11
- CMake
- Visual Studio 2022 或 Build Tools 2022
- Desktop development with C++

SDL2 由 CMake 自动处理，不需要手动安装。

### 编译

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

构建完成后仍然使用：

```powershell
.\tools\run.ps1 "<firmware.elf>"
```

启动固件。

---

# 当前限制

目前主要支持：

- Windows x64
- STM32F103C8T6
- GPIO
- I2C1
- SSD1306 OLED
- HAL 轮询式 I2C

UART、SPI、ADC、PWM 等外设仍在后续开发中。
在使用过程中有bug的请发送邮件至mr.kuzumi0601@outlook.com

---

## License

本项目使用的第三方组件包括：

- [Renode](https://github.com/renode/renode)
- [SDL2](https://www.libsdl.org/)

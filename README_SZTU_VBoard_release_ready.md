# SZTU_VBoard

SZTU_VBoard 是一个基于 **Renode + SDL2** 的 Windows 虚拟 STM32F103C8T6 开发板。

它可以直接运行 STM32 工程生成的 `.elf` / `.axf` 固件，并在虚拟开发板界面中显示 GPIO、按键和 SSD1306 OLED 的实际运行结果。

> 适合 STM32 HAL 学习、基础外设实验，以及没有实体开发板时的程序验证。

---

## 当前支持

- STM32F103C8T6
- GPIO 输入 / 输出
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

## 普通用户：直接下载 Release

前往：

[GitHub Releases](https://github.com/Mrkuzumi/SZTU_VBoard/releases/latest)

下载：

```text
SZTU_VBoard-windows-x64.zip
```

解压后，第一次使用执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_runtime.ps1
```

该脚本会自动准备 Renode 运行环境，之后无需重复下载。

然后运行 STM32 固件：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 "<firmware.elf>"
```

Keil 生成的 `.axf` 也可以直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 "<firmware.axf>"
```

例如 CubeIDE 当前使用 Debug 配置时：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 "..\MySTM32Project\Debug\MySTM32Project.elf"
```

> SZTU_VBoard 不要求固定使用 Debug 或 Release，只需要传入你当前实际生成的固件文件。

---

# STM32CubeIDE 配置

使用 STM32CubeIDE 正常创建并编译 STM32F103C8T6 工程即可。

## GPIO 输出

例如使用 PC13 控制 LED0：

```c
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET);
HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
```

## 按键输入

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

## SSD1306 OLED

CubeMX 配置：

```text
I2C1
PB6 = I2C1_SCL
PB7 = I2C1_SDA
100 kHz
7-bit address
```

HAL 地址：

```c
#define SSD1306_ADDR (0x3C << 1)
```

当前已验证：

```c
HAL_I2C_IsDeviceReady()
HAL_I2C_Master_Transmit()
```

常见的 SSD1306 HAL 轮询式驱动可以使用。

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

再次启动新的虚拟板时，旧实例会自动退出。

---

# 从源码开发

如果你需要修改 SZTU_VBoard 本身：

```powershell
git clone https://github.com/Mrkuzumi/SZTU_VBoard.git
cd SZTU_VBoard
```

开发环境：

- Windows 10 / 11 x64
- CMake
- Visual Studio 2022 或 Build Tools 2022
- Desktop development with C++

SDL2 由 CMake 自动处理，不需要单独安装。

编译：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

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
├─ CMakeLists.txt
└─ README.md
```

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

如果遇到问题，建议通过 GitHub Issues 提交复现步骤和相关日志。或联系mr.kuzumi0601@outlook.com

---

## 第三方组件

- [Renode](https://github.com/renode/renode)
- [SDL2](https://www.libsdl.org/)

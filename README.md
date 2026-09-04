# VirtualSTM32F103C8T6

一个面向 STM32 入门与教学的 Windows 虚拟开发板。

项目使用 **Renode** 执行真实的 STM32F103C8T6 ELF/AXF 固件，使用 **SDL2** 绘制开发板界面。用户程序中的 GPIO、I2C 等操作会经过 Renode 的 MCU/外设模型，再反映到虚拟 LED、按键和 OLED 上，而不是在 GUI 中写死行为。

## 当前支持

| 功能 | 状态 |
|---|---|
| MCU | STM32F103C8T6 |
| 固件 | `.elf` / `.axf` |
| GPIO 输出 | PC13、PA0、PA1、PA2 |
| GPIO 输入 | PB12、PB13、PB14、PB15 |
| SSD1306 | 128×64，I2C1，地址 `0x3C` |
| STM32 HAL | GPIO；I2C 轮询方式已验证 |
| GDB Server | `127.0.0.1:3333` |
| Windows GUI | SDL2 |
| 后端 | Renode 1.16.1 |
| 多开策略 | 后启动实例替换先启动实例 |

### 板载引脚

| 虚拟外设 | STM32 引脚 | 逻辑 |
|---|---|---|
| LED0 | PC13 | HIGH = ON |
| LED1 | PA0 | HIGH = ON |
| LED2 | PA1 | HIGH = ON |
| LED3 | PA2 | HIGH = ON |
| KEY0 | PB12 | 按下 = LOW |
| KEY1 | PB13 | 按下 = LOW |
| KEY2 | PB14 | 按下 = LOW |
| KEY3 | PB15 | 按下 = LOW |
| OLED SCL | PB6 / I2C1_SCL | 100 kHz 推荐 |
| OLED SDA | PB7 / I2C1_SDA | SSD1306 `0x3C` |

> KEY0~KEY3 建议在 CubeMX 中配置为 `GPIO_Input + Pull-up`。

---

# 快速开始

## 方法 A：普通使用者——推荐

普通使用者**不需要安装 Visual Studio、CMake、Python、SDL2 开发包或单独的 .NET SDK**。

需要的只有：

1. 一个已经编译好的 STM32F103 `.elf` 或 `.axf`
2. 本项目的 Windows Release
3. 第一次使用时下载一次 Renode portable runtime

下载项目 Release 后，在目录中执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_runtime.ps1
```

该脚本会把 Renode 安装到：

```text
%LOCALAPPDATA%\VirtualSTM32\renode\1.16.1
```

Renode **不会放进本项目目录，也不会提交到 Git**。

然后运行固件：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 `
  "D:\STM32_Project\Debug\firmware.elf"
```

Keil 生成的 AXF 也可以：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 `
  "D:\Keil_Project\Objects\firmware.axf"
```

---

## 方法 B：从 GitHub clone 后直接使用

```powershell
git clone <your-repository-url>
cd VirtualSTM32F103C8T6
```

执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup.ps1
```

`setup.ps1` 会：

1. 安装/复用本机缓存的 Renode runtime；
2. 优先使用本机已经编译好的 `VirtualSTM32.exe`；
3. 如果本地没有可执行文件，则从当前 GitHub 仓库的 **Latest Release** 下载预编译 Windows 版本；
4. 所有大型运行时与构建缓存均放在 `%LOCALAPPDATA%\VirtualSTM32`，不会污染 Git 仓库。

之后：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run.ps1 `
  "D:\STM32_Project\Debug\firmware.elf"
```

---

# STM32CubeIDE 使用

在 CubeIDE 中正常创建 STM32F103C8T6 工程并编译即可。

虚拟板**不要求固件必须是 Debug 或 Release**，只需要把实际生成的 ELF 路径传给启动器。

例如：

```text
MyProject\
├─ Debug\
│  └─ MyProject.elf
└─ Release\
   └─ MyProject.elf
```

如果当前 CubeIDE Build Configuration 是 Debug：

```powershell
.\tools\run.ps1 "D:\MyProject\Debug\MyProject.elf"
```

如果切换为 Release：

```powershell
.\tools\run.ps1 "D:\MyProject\Release\MyProject.elf"
```

不要把 `Debug` / `Release` 路径写死在工程中。

---

# Keil 使用

Keil MDK 通常生成 ELF 格式的 `.axf`：

```text
Objects\ProjectName.axf
```

直接传入即可：

```powershell
.\tools\run.ps1 "D:\KeilProject\Objects\ProjectName.axf"
```

---

# HAL 示例

## LED

PC13 配置为推挽输出后：

```c
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);   // LED0 ON
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_RESET); // LED0 OFF
HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
```

## 按键

KEY0 为 PB12，低电平按下：

```c
if (HAL_GPIO_ReadPin(GPIOB, GPIO_PIN_12) == GPIO_PIN_RESET)
{
    // KEY0 pressed
}
```

推荐使用下降沿检测或“按下后等待松开”，不要在按住期间连续 Toggle。

## SSD1306

CubeMX：

```text
I2C1
PB6 = I2C1_SCL
PB7 = I2C1_SDA
100 kHz
7-bit
```

HAL 地址：

```c
#define SSD1306_ADDR (0x3C << 1)
```

当前已验证：

```c
HAL_I2C_IsDeviceReady(...)
HAL_I2C_Master_Transmit(...)
```

常规的“初始化 SSD1306 + 写 1024 字节 framebuffer”的 HAL 轮询式驱动可以使用。

DMA / Interrupt I2C 路径目前不作为已验证功能保证。

---

# GUI 状态

右上角 BACKEND 指示灯：

| 颜色 | 含义 |
|---|---|
| 黄 | Renode / External Control 正在启动 |
| 绿 | 后端已经连接 |
| 红 | 后端不可用 |

快捷键：

```text
R    重新加载当前固件
Esc  退出虚拟板
```

关闭 GUI 时，VirtualSTM32 会清理它启动的 Renode 进程树。

再次启动新的 VirtualSTM32 时，旧实例会自动退出，新的实例接管后端，避免 `3333 / 33334 / 33335` 被旧实例占用。

---

# 工作原理

```text
STM32 ELF / AXF
      │
      ▼
    Renode
 STM32F103C8T6
      │
      ├── GPIO output ──> External Control ──> LED
      │
      ├── GUI KEY ──────> External Control ──> GPIO input
      │
      └── I2C1 ─────────> SSD1306 bridge ───> OLED framebuffer
                                             │
                                             ▼
                                            SDL2
```

GUI 不直接模拟用户程序逻辑。

例如：

```text
HAL_GPIO_ReadPin(PB12)
```

读取的是 Renode 中的 GPIO 输入状态；

```text
HAL_GPIO_WritePin(PC13)
```

改变的是 Renode 中的 GPIO 输出，再由 GUI 读取并显示。

OLED 同理：

```text
HAL_I2C_Master_Transmit
        ↓
Renode I2C1
        ↓
SSD1306 @ 0x3C
        ↓
128×64 framebuffer
        ↓
SDL2
```

---

# 仓库结构

正式仓库只保留源码、资源和必要脚本：

```text
VirtualSTM32F103C8T6/
├─ .github/
│  └─ workflows/
│     └─ windows-release.yml
├─ assets/
│  ├─ board.bmp
│  ├─ led_*.bmp
│  ├─ button_*.bmp
│  └─ oled_module.bmp
├─ renode/
│  └─ ssd1306_bridge_mem.py
├─ src/
│  ├─ main.cpp
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
│  ├─ build.ps1
│  └─ repo_slim.ps1
├─ CMakeLists.txt
├─ .gitignore
└─ README.md
```

以下内容**不进入 Git 仓库**：

```text
build/
third_party/renode/
.vs/
CMake 缓存
SDL2 FetchContent 构建缓存
旧 patch / diagnostic 脚本
*.preXXX.bak
Download/
Renode portable runtime
```

---

# 为什么仓库可以保持很小

本项目采用“**源码仓库轻量化，运行时按需缓存**”方案。

## Renode

Renode 是最大的运行依赖，但不需要放进仓库。

首次执行：

```powershell
.\tools\setup_runtime.ps1
```

后，Renode 缓存到：

```text
%LOCALAPPDATA%\VirtualSTM32\renode\1.16.1
```

多个 clone 可以共用这一份。

## SDL2

普通用户使用 Release 中附带的 `SDL2.dll`，不需要安装 SDL2。

只有修改 VirtualSTM32 本身、从源码编译时，CMake 才会通过 `FetchContent` 获取 SDL2 源码。

## 构建目录

开发者构建默认使用：

```text
%LOCALAPPDATA%\VirtualSTM32\build\
```

而不是仓库里的 `build/`。

因此 CMake、MSVC、SDL2 的中间文件不会让 Git 工作区膨胀。

---

# 从源码开发 VirtualSTM32

这一部分只面向修改虚拟板本身的开发者。

普通使用者不需要安装这些东西。

要求：

- Windows 10 / 11 x64
- CMake 3.22+
- Visual Studio 2022 Build Tools 或 Visual Studio 2022
- `Desktop development with C++`

SDL2 不需要手动安装。

执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

默认构建目录：

```text
%LOCALAPPDATA%\VirtualSTM32\build\VirtualSTM32F103C8T6
```

构建完成后可直接：

```powershell
.\tools\run.ps1 "D:\firmware.elf"
```

---

# 发布

仓库中的 GitHub Actions 会在 Windows Runner 上自动构建 Release。

建议发布流程：

```text
git tag v0.x.x
git push origin v0.x.x
```

Tag 构建会生成：

```text
VirtualSTM32-windows-x64.zip
```

Release 包只包含 VirtualSTM32、SDL2 运行库、GUI assets 和必要的 Renode bridge。

**不会把 100+ MB 的 Renode runtime 塞进 Release 或 Git 历史。**

Renode 由 `setup_runtime.ps1` 单独下载并缓存。

---

# 清理现有大工程目录

先预览：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\repo_slim.ps1
```

确认后执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\repo_slim.ps1 `
  -Apply `
  -MoveRenodeToCache
```

它会清理：

- 仓库内 `build/`
- `.vs/`
- 旧 `*.preXXX.bak`
- 已废弃的重复源码
- 已废弃的旧 Renode bridge
- 顶层重复 bridge 文件

并把项目内已经存在的：

```text
third_party\renode
```

移动到：

```text
%LOCALAPPDATA%\VirtualSTM32\renode\1.16.1
```

这样既不会重新下载，也不会继续占用仓库目录。

---

# 当前限制

- 目前正式目标平台为 Windows x64。
- MCU 当前固定为 STM32F103C8T6。
- OLED 当前重点验证的是 SSD1306 + I2C1 + HAL 轮询式驱动。
- GDB Server 已提供，但 CubeIDE / Keil “点击 Download 后自动启动虚拟板”的一键集成仍属于后续功能。
- UART、SPI、ADC 等外设还没有纳入当前正式板卡。

---

# 第三方项目

VirtualSTM32 使用：

- Renode — Antmicro，MIT License
- SDL2 — zlib License

Renode 官方项目：

https://github.com/renode/renode

SDL：

https://www.libsdl.org/

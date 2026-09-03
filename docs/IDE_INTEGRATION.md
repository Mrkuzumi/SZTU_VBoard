# IDE integration notes

## STM32CubeIDE

CubeIDE 的构建系统会产生 `BUILD_ARTIFACT` / `BUILD_ARTIFACT_NAME` / `BUILD_ARTIFACT_EXTENSION` 等宏。项目包中的 `tools/cubeide_makefile.targets.example` 直接依赖 `BUILD_ARTIFACT`，因此不用猜 Debug/Release 目录和工程名。

目标体验：

```text
Ctrl+B / Run
   -> GCC link .elf
   -> makefile.targets
   -> ide_launch.cmd <absolute ELF>
   -> terminate previous VirtualSTM32.exe
   -> launch new VirtualSTM32.exe
   -> Renode loads ELF and start
```

实体 ST-Link 的 Download 和虚拟运行是两种目标。若你希望“点击 Run 就只跑虚拟板”，建议单独建一个 CubeIDE Build Configuration，例如 `VirtualDebug`，只在该 configuration 启用 `makefile.targets`。

## Keil5

Keil `Options for Target -> User -> After Build/Rebuild` 支持成功构建后启动外部程序。
推荐命令：

```text
"C:\\Tools\\VirtualSTM32F103C8T6\\tools\\ide_launch.cmd" "#L"
```

这里 `#` 表示完整路径、`L` 表示 linker output，因此 `#L` 会把完整 AXF/ELF 路径交给 VirtualSTM32。VirtualSTM32 直接接受 `.axf`。

## Later: true Debug integration

V0.1 先自动运行。下一阶段建议做：

1. VirtualSTM32 启动 Renode，但先 pause
2. `machine StartGdbServer 3333`
3. CubeIDE 建一个 Remote GDB launch，target `localhost:3333`
4. 点击 Debug 时 IDE 自动 build -> launch virtual board -> attach GDB

这样就能做到源码断点、Step Into/Over、寄存器窗口和 Call Stack。

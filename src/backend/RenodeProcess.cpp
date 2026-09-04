#include "backend/RenodeProcess.h"

#include <cstdlib>
#include <fstream>
#include <sstream>
#include <utility>
#include <vector>

RenodeProcess::~RenodeProcess()
{
    Stop();
}

std::filesystem::path RenodeProcess::FindRenode(
    const std::filesystem::path& appDir,
    const std::filesystem::path& explicitRenode)
{
    if(!explicitRenode.empty() &&
       std::filesystem::exists(explicitRenode)) {
        return explicitRenode;
    }

    if(const wchar_t* env = _wgetenv(L"RENODE_PATH")) {
        std::filesystem::path path(env);
        if(std::filesystem::is_directory(path)) path /= "renode.exe";
        if(std::filesystem::exists(path)) return path;
    }

    // Shared lightweight runtime cache.
    // Large Renode files live outside the Git repository.
    if(const wchar_t* localAppData = _wgetenv(L"LOCALAPPDATA")) {
        const auto cached =
            std::filesystem::path(localAppData) /
            "VirtualSTM32" /
            "renode" /
            "1.16.1" /
            "renode.exe";

        if(std::filesystem::exists(cached)) {
            return cached;
        }
    }

    std::filesystem::path cursor = appDir;
    for(int i = 0; i < 4; ++i) {
        const auto portable =
            cursor / "third_party" / "renode" / "renode.exe";

        if(std::filesystem::exists(portable)) return portable;

        if(!cursor.has_parent_path()) break;
        const auto parent = cursor.parent_path();
        if(parent == cursor) break;
        cursor = parent;
    }

    return L"renode.exe";
}

std::wstring RenodeProcess::Quote(const std::filesystem::path& path)
{
    return L"\"" + path.wstring() + L"\"";
}

bool RenodeProcess::WriteRuntimeScript(
    const std::filesystem::path& elf,
    const std::filesystem::path& appDir,
    const RenodeRuntimeOptions& options,
    std::string& error)
{
    char temp[MAX_PATH]{};
    if(GetTempPathA(MAX_PATH, temp) == 0) {
        error = "GetTempPathA failed.";
        return false;
    }

    const auto runtimeDir =
        std::filesystem::path(temp) / "VirtualSTM32";

    std::error_code ec;
    std::filesystem::create_directories(runtimeDir, ec);
    if(ec) {
        error = "Cannot create runtime directory: " +
                runtimeDir.u8string();
        return false;
    }

    const auto runtimeElf = runtimeDir / "firmware.elf";
    const auto overlay = runtimeDir / "vboard_runtime.repl";
    runtimeScript_ = runtimeDir / "runtime.resc";

    const auto sourceBridge =
        appDir / "renode" / "ssd1306_bridge_mem.py";
    const auto runtimeBridge =
        runtimeDir / "ssd1306_bridge_mem.py";

    if(!std::filesystem::exists(sourceBridge)) {
        error = "Missing SSD1306 bridge: " +
                sourceBridge.u8string();
        return false;
    }

    std::filesystem::copy_file(
        sourceBridge,
        runtimeBridge,
        std::filesystem::copy_options::overwrite_existing,
        ec
    );

    if(ec) {
        error = "Cannot copy SSD1306 bridge into Renode runtime directory: " +
                ec.message();
        return false;
    }
    // Proven Windows/Renode rule:
    // copy the ELF into Renode's working directory and use @firmware.elf.
    std::filesystem::copy_file(
        elf,
        runtimeElf,
        std::filesystem::copy_options::overwrite_existing,
        ec
    );

    if(ec) {
        error =
            "Cannot copy firmware ELF into Renode runtime directory.\n"
            "Source: " + elf.u8string() + "\n"
            "Destination: " + runtimeElf.u8string() + "\n"
            "Error: " + ec.message();
        return false;
    }

    // Runtime-only wiring.
    //
    // External Control GET_STATE observes GPIO input-side state, so each
    // visible output is mirrored into a hidden sink pin:
    //
    //   PC13 -> PB0
    //   PA0  -> PB1
    //   PA1  -> PB2
    //   PA2  -> PB3
    //
    // This was validated independently by Patch 020.
    std::ofstream repl(overlay,
                       std::ios::binary | std::ios::trunc);
    if(!repl) {
        error = "Cannot create runtime overlay: " +
                overlay.u8string();
        return false;
    }
    repl << "gpioPortC:\n";
    repl << "    13 -> gpioPortB@0\n\n";

    repl << "gpioPortA:\n";
    repl << "    0 -> gpioPortB@1\n";
    repl << "    1 -> gpioPortB@2\n";
    repl << "    2 -> gpioPortB@3\n";
    repl << "\n";

    // Patch 033A:
    // Real Renode I2C target attached to STM32F103 I2C1.
    // Renode uses the 7-bit slave address here: 0x3C.
    repl << "ssd1306: Mocks.DummyI2CSlave @ i2c1 0x3C\n";
    repl << "\n";
    // Patch 033B5:
    // Do NOT register another Memory.MappedMemory at 0x60000000.
    // Renode's stock stm32f103.repl already maps fsmcBank1 there
    // (0x60000000..0x6FFFFFFF). The OLED bridge reserves only the
    // first 0x1000 bytes of that already-existing backing memory.
    repl.flush();

    if(!repl) {
        error = "Failed while writing runtime overlay: " +
                overlay.u8string();
        return false;
    }

    std::ofstream resc(runtimeScript_,
                       std::ios::binary | std::ios::trunc);
    if(!resc) {
        error = "Cannot create runtime Renode script: " +
                runtimeScript_.u8string();
        return false;
    }

    resc << "using sysbus\n";
    resc << "mach create \"vstm32\"\n";
    resc << "log \"VSTM32_STAGE_MACHINE_CREATED\"\n";

    resc << "machine LoadPlatformDescription "
            "@platforms/cpus/stm32f103.repl\n";
    resc << "machine LoadPlatformDescription "
            "@vboard_runtime.repl\n";
    resc << "log \"VSTM32_STAGE_PLATFORM_LOADED\"\n";
    resc << "sysbus LoadELF @firmware.elf\n";
    resc << "log \"VSTM32_STAGE_ELF_LOADED\"\n";

    resc << "emulation CreateExternalControlServer "
            "\"vboard-api\" "
         << options.externalControlPort << "\n";
    resc << "log \"VSTM32_STAGE_EXTERNAL_CONTROL_STARTED\"\n";

    resc << "machine StartGdbServer "
         << options.gdbPort << "\n";
    resc << "log \"VSTM32_STAGE_GDB_STARTED\"\n";
    // OLED scripting is deliberately non-boot-critical.
    resc << "include @ssd1306_bridge_mem.py\n";
    resc << "log \"VSTM32_STAGE_SSD1306_BRIDGE_LOADED\"\n";

    resc << "start\n";
    resc << "log \"VSTM32_STAGE_EMULATION_STARTED\"\n";
    resc.flush();

    if(!resc) {
        error = "Failed while writing runtime script: " +
                runtimeScript_.u8string();
        return false;
    }

    return true;
}

bool RenodeProcess::Start(
    const std::filesystem::path& elf,
    const std::filesystem::path& appDir,
    const std::filesystem::path& explicitRenode,
    const RenodeRuntimeOptions& options,
    std::string& error)
{
    Stop();

    if(!std::filesystem::exists(elf)) {
        error = "ELF file does not exist: " +
                elf.u8string();
        return false;
    }

    if(!WriteRuntimeScript(elf, appDir, options, error)) {
        return false;
    }

    const auto renode =
        FindRenode(appDir, explicitRenode);

    const auto runtimeDir =
        runtimeScript_.parent_path();
    const auto startupLog =
        runtimeDir / "renode-startup.log";

    HANDLE logHandle = CreateFileW(
        startupLog.wstring().c_str(),
        GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        nullptr,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr
    );

    if(logHandle == INVALID_HANDLE_VALUE) {
        error = "Cannot create Renode startup log: " +
                startupLog.u8string();
        return false;
    }

    std::wostringstream commandBuilder;
    commandBuilder
        << Quote(renode)
        << L" -P " << options.monitorPort
        << L" -p --disable-gui --hide-analyzers"
        << L" -e \"include @runtime.resc\"";

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    si.dwFlags |= STARTF_USESTDHANDLES;
    si.hStdOutput = logHandle;
    si.hStdError = logHandle;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    std::wstring command = commandBuilder.str();
    std::vector<wchar_t> mutableCommand(
        command.begin(), command.end()
    );
    mutableCommand.push_back(L'\0');

    const std::wstring workingDirectory =
        runtimeDir.wstring();

    // ---------------------------------------------------------------
    // Patch 034:
    // Own Renode and all of its descendants with a Windows Job Object.
    //
    // KILL_ON_JOB_CLOSE is the important part:
    // if VirtualSTM32 closes normally OR crashes/gets terminated,
    // Windows closes this process's job handle and kills the complete
    // Renode process tree automatically.
    // ---------------------------------------------------------------
    job_ = CreateJobObjectW(nullptr, nullptr);

    if(!job_) {
        const DWORD windowsError = GetLastError();

        CloseHandle(logHandle);

        error =
            "CreateJobObjectW failed. Windows error=" +
            std::to_string(windowsError);

        return false;
    }

    JOBOBJECT_EXTENDED_LIMIT_INFORMATION jobInfo{};
    jobInfo.BasicLimitInformation.LimitFlags =
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

    if(!SetInformationJobObject(
           job_,
           JobObjectExtendedLimitInformation,
           &jobInfo,
           sizeof(jobInfo))) {

        const DWORD windowsError = GetLastError();

        CloseHandle(job_);
        job_ = nullptr;

        CloseHandle(logHandle);

        error =
            "SetInformationJobObject failed. Windows error=" +
            std::to_string(windowsError);

        return false;
    }

    const BOOL ok = CreateProcessW(
        nullptr,
        mutableCommand.data(),
        nullptr,
        nullptr,
        TRUE,
        CREATE_NO_WINDOW | CREATE_SUSPENDED,
        nullptr,
        workingDirectory.c_str(),
        &si,
        &pi_
    );

    CloseHandle(logHandle);

    if(!ok) {
        error =
            "Failed to launch Renode. Windows error=" +
            std::to_string(GetLastError()) +
            "\nStartup log: " + startupLog.u8string();

        
        // Patch 034 create-process failure cleanup.
        if(job_) {
            CloseHandle(job_);
            job_ = nullptr;
        }
ZeroMemory(&pi_, sizeof(pi_));
        return false;
    }

    // Attach while the process is still suspended. This guarantees that
    // Renode cannot spawn descendants before entering our Job Object.
    if(!AssignProcessToJobObject(job_, pi_.hProcess)) {
        const DWORD windowsError = GetLastError();

        TerminateProcess(pi_.hProcess, 1);
        WaitForSingleObject(pi_.hProcess, 1000);

        CloseHandle(pi_.hThread);
        CloseHandle(pi_.hProcess);
        ZeroMemory(&pi_, sizeof(pi_));

        CloseHandle(job_);
        job_ = nullptr;

        error =
            "AssignProcessToJobObject failed. Windows error=" +
            std::to_string(windowsError);

        return false;
    }

    if(ResumeThread(pi_.hThread) == static_cast<DWORD>(-1)) {
        const DWORD windowsError = GetLastError();

        TerminateJobObject(job_, 1);
        WaitForSingleObject(pi_.hProcess, 1000);

        CloseHandle(pi_.hThread);
        CloseHandle(pi_.hProcess);
        ZeroMemory(&pi_, sizeof(pi_));

        CloseHandle(job_);
        job_ = nullptr;

        error =
            "ResumeThread(Renode) failed. Windows error=" +
            std::to_string(windowsError);

        return false;
    }
    // Only detect immediate process launch failures.
    if(WaitForSingleObject(pi_.hProcess, 250) != WAIT_TIMEOUT) {
        DWORD exitCode = 0;
        GetExitCodeProcess(pi_.hProcess, &exitCode);

        error =
            "Renode exited during startup (exit code " +
            std::to_string(exitCode) + ").\n" +
            "Startup log: " + startupLog.u8string() + "\n" +
            "Runtime script: " + runtimeScript_.u8string();

        CloseHandle(pi_.hThread);
        CloseHandle(pi_.hProcess);
        ZeroMemory(&pi_, sizeof(pi_));
        return false;
    }

    return true;
}

void RenodeProcess::Stop()
{
    // Prefer terminating the Job Object because it owns the complete
    // Renode process tree, not only the direct renode.exe process.
    if(job_) {
        TerminateJobObject(job_, 0);
    }
    else if(pi_.hProcess &&
            WaitForSingleObject(pi_.hProcess, 0) == WAIT_TIMEOUT) {
        // Compatibility fallback for a process created before the Job
        // Object was available.
        TerminateProcess(pi_.hProcess, 0);
    }

    if(pi_.hProcess) {
        WaitForSingleObject(pi_.hProcess, 1500);
    }

    if(pi_.hThread) {
        CloseHandle(pi_.hThread);
    }

    if(pi_.hProcess) {
        CloseHandle(pi_.hProcess);
    }

    ZeroMemory(&pi_, sizeof(pi_));

    // Closing a KILL_ON_JOB_CLOSE job handle is also the final safety net.
    if(job_) {
        CloseHandle(job_);
        job_ = nullptr;
    }
}

bool RenodeProcess::Running() const
{
    return pi_.hProcess &&
           WaitForSingleObject(pi_.hProcess, 0) ==
               WAIT_TIMEOUT;
}









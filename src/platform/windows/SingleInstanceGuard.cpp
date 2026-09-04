#include "platform/windows/SingleInstanceGuard.h"

#include <tlhelp32.h>

#include <cwchar>
#include <string>

namespace {

constexpr wchar_t kMutexName[] =
    L"Local\\VirtualSTM32F103C8T6.SingleInstance";

constexpr wchar_t kReplaceEventName[] =
    L"Local\\VirtualSTM32F103C8T6.ReplaceRequested";

std::wstring CurrentExecutablePath()
{
    std::wstring buffer(32768, L'\0');

    DWORD size = static_cast<DWORD>(buffer.size());
    if(GetModuleFileNameW(nullptr, buffer.data(), size) == 0) {
        return {};
    }

    buffer.resize(std::wcslen(buffer.c_str()));
    return buffer;
}

bool SameExecutablePath(HANDLE process,
                        const std::wstring& currentPath)
{
    std::wstring path(32768, L'\0');
    DWORD length = static_cast<DWORD>(path.size());

    if(!QueryFullProcessImageNameW(
           process,
           0,
           path.data(),
           &length)) {
        return false;
    }

    path.resize(length);

    return _wcsicmp(
               path.c_str(),
               currentPath.c_str()) == 0;
}

} // namespace

SingleInstanceGuard::~SingleInstanceGuard()
{
    // The App destructor has already shut down Renode before this member
    // destructor executes, so releasing the mutex means "backend is gone".
    if(ownsMutex_ && mutex_) {
        ReleaseMutex(mutex_);
    }

    ownsMutex_ = false;

    if(mutex_) {
        CloseHandle(mutex_);
        mutex_ = nullptr;
    }

    if(replaceEvent_) {
        CloseHandle(replaceEvent_);
        replaceEvent_ = nullptr;
    }
}

bool SingleInstanceGuard::ForceCloseOtherCopiesOfThisExecutable()
{
    const std::wstring currentPath = CurrentExecutablePath();
    if(currentPath.empty()) {
        return false;
    }

    const DWORD selfPid = GetCurrentProcessId();

    HANDLE snapshot = CreateToolhelp32Snapshot(
        TH32CS_SNAPPROCESS,
        0
    );

    if(snapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);

    bool terminatedAny = false;

    if(Process32FirstW(snapshot, &entry)) {
        do {
            if(entry.th32ProcessID == selfPid) {
                continue;
            }

            HANDLE process = OpenProcess(
                PROCESS_QUERY_LIMITED_INFORMATION |
                PROCESS_TERMINATE |
                SYNCHRONIZE,
                FALSE,
                entry.th32ProcessID
            );

            if(!process) {
                continue;
            }

            if(SameExecutablePath(process, currentPath)) {
                if(TerminateProcess(process, 0)) {
                    WaitForSingleObject(process, 2500);
                    terminatedAny = true;
                }
            }

            CloseHandle(process);
        }
        while(Process32NextW(snapshot, &entry));
    }

    CloseHandle(snapshot);
    return terminatedAny;
}

bool SingleInstanceGuard::AcquireOrReplaceExisting(
    std::string& error)
{
    // Auto-reset event: the currently-running copy consumes one replace
    // request and exits its SDL event loop.
    replaceEvent_ = CreateEventW(
        nullptr,
        FALSE,
        FALSE,
        kReplaceEventName
    );

    if(!replaceEvent_) {
        error =
            "CreateEventW(single-instance replace event) failed. "
            "Windows error=" +
            std::to_string(GetLastError());
        return false;
    }

    // If this is the first copy, TRUE grants us initial ownership.
    mutex_ = CreateMutexW(
        nullptr,
        TRUE,
        kMutexName
    );

    if(!mutex_) {
        error =
            "CreateMutexW(single-instance mutex) failed. Windows error=" +
            std::to_string(GetLastError());
        return false;
    }

    const DWORD createError = GetLastError();

    if(createError != ERROR_ALREADY_EXISTS) {
        ownsMutex_ = true;
        ResetEvent(replaceEvent_);
        return true;
    }

    // Another VBoard is alive. Ask it to perform its normal Shutdown():
    // External Control -> Renode Job Object -> SDL resources.
    SetEvent(replaceEvent_);

    DWORD wait = WaitForSingleObject(mutex_, 3000);

    if(wait == WAIT_OBJECT_0 ||
       wait == WAIT_ABANDONED) {
        ownsMutex_ = true;
        ResetEvent(replaceEvent_);
        return true;
    }

    if(wait != WAIT_TIMEOUT) {
        error =
            "Waiting for the previous VirtualSTM32 instance failed. "
            "Windows error=" +
            std::to_string(GetLastError());
        return false;
    }

    // The old GUI did not respond to the graceful request. As a fallback,
    // terminate only another process whose FULL executable path is identical
    // to this VirtualSTM32.exe. Patch 034's Job Object then removes Renode.
    ForceCloseOtherCopiesOfThisExecutable();

    wait = WaitForSingleObject(mutex_, 3000);

    if(wait == WAIT_OBJECT_0 ||
       wait == WAIT_ABANDONED) {
        ownsMutex_ = true;
        ResetEvent(replaceEvent_);
        return true;
    }

    error =
        "The previous VirtualSTM32 instance could not be replaced within "
        "6 seconds. Close it manually and try again.";

    return false;
}

bool SingleInstanceGuard::ReplacementRequested() const noexcept
{
    if(!replaceEvent_) {
        return false;
    }

    return WaitForSingleObject(
               replaceEvent_,
               0) == WAIT_OBJECT_0;
}

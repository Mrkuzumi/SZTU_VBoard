#pragma once

#include <windows.h>

#include <string>

// Enforces one VirtualSTM32 GUI instance per Windows user session.
//
// Starting a second copy:
//   1. signals the first copy to shut down cleanly;
//   2. waits until its Renode backend is stopped;
//   3. if the old GUI is unresponsive, force-terminates only another
//      VirtualSTM32.exe with the exact same executable path;
//   4. lets the new copy continue.
class SingleInstanceGuard {
public:
    SingleInstanceGuard() = default;
    ~SingleInstanceGuard();

    SingleInstanceGuard(const SingleInstanceGuard&) = delete;
    SingleInstanceGuard& operator=(const SingleInstanceGuard&) = delete;

    bool AcquireOrReplaceExisting(std::string& error);
    bool ReplacementRequested() const noexcept;

private:
    static bool ForceCloseOtherCopiesOfThisExecutable();

    HANDLE mutex_ = nullptr;
    HANDLE replaceEvent_ = nullptr;
    bool ownsMutex_ = false;
};

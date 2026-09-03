#pragma once
#include <windows.h>
#include <filesystem>
#include <string>

class RenodeProcess {
public:
    RenodeProcess() = default;
    ~RenodeProcess();

    bool Start(const std::filesystem::path& elf,
               const std::filesystem::path& appDir,
               const std::filesystem::path& explicitRenode,
               int monitorPort,
               std::string& error);
    void Stop();
    bool Running() const;
    std::filesystem::path RuntimeScript() const { return runtimeScript_; }

private:
    static std::filesystem::path FindRenode(const std::filesystem::path& appDir,
                                             const std::filesystem::path& explicitRenode);
    static std::wstring Quote(const std::filesystem::path& p);
    static std::string RenodePath(const std::filesystem::path& p);
    bool WriteRuntimeScript(const std::filesystem::path& elf,
                            const std::filesystem::path& appDir,
                            std::string& error);

    PROCESS_INFORMATION pi_{};
    std::filesystem::path runtimeScript_;
};

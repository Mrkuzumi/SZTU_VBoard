#pragma once
#include <array>
#include <cstdint>
#include <filesystem>

class OledFramebuffer {
public:
    OledFramebuffer();
    bool Poll();
    const std::array<uint8_t, 1024>& Data() const { return data_; }
    std::filesystem::path FilePath() const { return filePath_; }

private:
    std::filesystem::path filePath_;
    std::array<uint8_t, 1024> data_{};
    std::filesystem::file_time_type lastWrite_{};
    bool hasTimestamp_ = false;
};

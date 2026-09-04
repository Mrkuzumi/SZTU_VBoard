#include "peripherals/OledFramebuffer.h"
#include <windows.h>
#include <fstream>

OledFramebuffer::OledFramebuffer()
{
    char temp[MAX_PATH]{};
    GetTempPathA(MAX_PATH, temp);
    filePath_ = std::filesystem::path(temp) / "VirtualSTM32" / "oled.bin";
}

bool OledFramebuffer::Poll()
{
    std::error_code ec;
    if(!std::filesystem::exists(filePath_, ec)) return false;
    auto wt = std::filesystem::last_write_time(filePath_, ec);
    if(ec) return false;
    if(hasTimestamp_ && wt == lastWrite_) return false;

    std::ifstream f(filePath_, std::ios::binary);
    if(!f) return false;
    f.read(reinterpret_cast<char*>(data_.data()), static_cast<std::streamsize>(data_.size()));
    if(f.gcount() != static_cast<std::streamsize>(data_.size())) return false;

    lastWrite_ = wt;
    hasTimestamp_ = true;
    return true;
}

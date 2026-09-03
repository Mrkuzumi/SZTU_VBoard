#pragma once
#include "BoardRenderer.h"
#include "MonitorClient.h"
#include "RenodeProcess.h"
#include "OledFramebuffer.h"
#include <SDL.h>
#include <array>
#include <filesystem>
#include <string>

class App {
public:
    App(std::filesystem::path elf, std::filesystem::path explicitRenode);
    ~App();
    int Run();

private:
    bool Initialize();
    void Shutdown();
    void HandleEvent(const SDL_Event& ev);
    void PollBoardState();
    void SetButton(size_t index, bool pressed);
    void ResetBoard();
    std::filesystem::path ExecutableDir() const;
    void SetWindowTitle(const std::string& suffix);

    std::filesystem::path elf_;
    std::filesystem::path explicitRenode_;
    std::filesystem::path appDir_;
    SDL_Window* window_ = nullptr;
    SDL_Renderer* renderer_ = nullptr;
    BoardRenderer board_;
    MonitorClient monitor_;
    RenodeProcess renode_;
    OledFramebuffer oled_;
    std::array<bool,4> ledOn_{};
    std::array<bool,4> buttonPressed_{};
    bool running_ = true;
    bool paused_ = false;
    bool connected_ = false;
    uint32_t lastPoll_ = 0;
};

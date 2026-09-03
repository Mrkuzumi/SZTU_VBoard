#include "App.h"
#include "BoardConfig.h"
#include <windows.h>
#include <sstream>
#include <iostream>
#include <utility>

App::App(std::filesystem::path elf, std::filesystem::path explicitRenode)
    : elf_(std::move(elf)), explicitRenode_(std::move(explicitRenode)) {}

App::~App() { Shutdown(); }

std::filesystem::path App::ExecutableDir() const
{
    wchar_t p[MAX_PATH]{};
    GetModuleFileNameW(nullptr, p, MAX_PATH);
    return std::filesystem::path(p).parent_path();
}

void App::SetWindowTitle(const std::string& suffix)
{
    if(!window_) return;
    std::string title = "Virtual STM32F103C8T6 Teaching Board - " + elf_.filename().u8string();
    if(!suffix.empty()) title += " - " + suffix;
    SDL_SetWindowTitle(window_, title.c_str());
}

bool App::Initialize()
{
    appDir_ = ExecutableDir();
    if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) != 0) return false;
    window_ = SDL_CreateWindow("Virtual STM32F103C8T6", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                               BoardConfig::WindowWidth, BoardConfig::WindowHeight, SDL_WINDOW_SHOWN);
    if(!window_) return false;
    renderer_ = SDL_CreateRenderer(window_, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if(!renderer_) renderer_ = SDL_CreateRenderer(window_, -1, SDL_RENDERER_SOFTWARE);
    if(!renderer_) return false;
    if(!board_.Initialize(renderer_, appDir_ / "assets")) return false;

    std::string error;
    if(!renode_.Start(elf_, appDir_, explicitRenode_, BoardConfig::MonitorPort, error)) {
        SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "VirtualSTM32 - Renode launch failed", error.c_str(), window_);
        SetWindowTitle("Renode unavailable");
        return true; // GUI still opens and shows disconnected state
    }

    connected_ = monitor_.Connect("127.0.0.1", BoardConfig::MonitorPort);
    if(connected_) {
        // Best effort: prepare future source-level debugging now.
        monitor_.Execute("machine StartGdbServer " + std::to_string(BoardConfig::GdbPort));
        // active-low keys: idle HIGH = Button.Release because teaching_board.repl uses invert:true.
        for(size_t i=0;i<BoardConfig::Buttons.size();++i) SetButton(i, false);
        SetWindowTitle("RUN | GDB :3333");
    } else {
        SetWindowTitle("monitor connection failed");
    }
    return true;
}

void App::Shutdown()
{
    monitor_.Disconnect();
    renode_.Stop();
    board_.Shutdown();
    if(renderer_) { SDL_DestroyRenderer(renderer_); renderer_ = nullptr; }
    if(window_) { SDL_DestroyWindow(window_); window_ = nullptr; }
    SDL_Quit();
}

void App::SetButton(size_t index, bool pressed)
{
    if(index >= BoardConfig::Buttons.size()) return;
    buttonPressed_[index] = pressed;
    if(!connected_) return;
    // teaching_board.repl uses invert:true, so Press drives the MCU input low.
    const auto cmd = std::string(BoardConfig::Buttons[index].monitorObject) + (pressed ? " Press" : " Release");
    monitor_.Execute(cmd);
}

void App::ResetBoard()
{
    if(!connected_) return;
    monitor_.Execute("machine Reset");
    for(size_t i=0;i<BoardConfig::Buttons.size();++i) SetButton(i, false);
    paused_ = false;
    SetWindowTitle("RESET | GDB :3333");
}

void App::HandleEvent(const SDL_Event& ev)
{
    if(ev.type == SDL_QUIT) { running_ = false; return; }
    if(ev.type == SDL_KEYDOWN) {
        if(ev.key.keysym.sym == SDLK_ESCAPE) running_ = false;
        if(ev.key.keysym.sym == SDLK_r) ResetBoard();
        if(ev.key.keysym.sym == SDLK_SPACE && connected_) {
            paused_ = !paused_;
            monitor_.Execute(paused_ ? "pause" : "start");
            SetWindowTitle(paused_ ? "PAUSED | GDB :3333" : "RUN | GDB :3333");
        }
    }
    if(ev.type == SDL_MOUSEBUTTONDOWN) {
        const int mx = ev.button.x, my = ev.button.y;
        for(size_t i=0;i<BoardConfig::Buttons.size();++i) {
            const auto& b = BoardConfig::Buttons[i];
            if(mx >= b.x && mx < b.x+b.w && my >= b.y && my < b.y+b.h) SetButton(i, true);
        }
    }
    if(ev.type == SDL_MOUSEBUTTONUP) {
        // Release every virtual key even if the cursor left the key before mouse-up.
        for(size_t i=0;i<BoardConfig::Buttons.size();++i) SetButton(i, false);
    }
}

void App::PollBoardState()
{
    oled_.Poll();
    if(!connected_) return;
    const uint32_t now = SDL_GetTicks();
    if(now - lastPoll_ < 80) return;
    lastPoll_ = now;

    for(size_t i=0;i<BoardConfig::LEDs.size();++i) {
        bool raw = false;
        std::string cmd = std::string(BoardConfig::LEDs[i].monitorObject) + " State";
        if(monitor_.QueryBool(cmd, raw)) ledOn_[i] = BoardConfig::LEDs[i].activeLow ? !raw : raw;
    }
}

int App::Run()
{
    if(!Initialize()) return 2;
    while(running_) {
        SDL_Event ev{};
        while(SDL_PollEvent(&ev)) HandleEvent(ev);
        PollBoardState();
        board_.Render(ledOn_, buttonPressed_, oled_.Data(), connected_, paused_);
        SDL_Delay(2);
    }
    return 0;
}

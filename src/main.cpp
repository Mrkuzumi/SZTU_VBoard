#include "app/App.h"
#include <SDL.h>
#include <windows.h>
#include <shellapi.h>
#include <filesystem>
#include <string>

static void Usage()
{
    MessageBoxA(nullptr,
        "Usage:\n  VirtualSTM32.exe --elf <firmware.elf> [--renode <renode.exe>]\n\n"
        "Keyboard:\n  R = Reload firmware\n  Esc = Exit",
        "VirtualSTM32F103C8T6", MB_OK | MB_ICONINFORMATION);
}

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
    int argc = 0;
    LPWSTR* argvW = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::filesystem::path elf;
    std::filesystem::path renode;
    for(int i=1;i<argc;++i) {
        std::wstring a = argvW[i];
        if(a == L"--elf" && i+1 < argc) elf = argvW[++i];
        else if(a == L"--renode" && i+1 < argc) renode = argvW[++i];
        else if(a.size() > 4 && (a.substr(a.size()-4) == L".elf" || a.substr(a.size()-4) == L".axf")) elf = a;
    }
    LocalFree(argvW);
    if(elf.empty()) { Usage(); return 1; }
    return App(std::filesystem::absolute(elf), renode).Run();
}


#include "MonitorClient.h"
#include <windows.h>
#include <algorithm>
#include <cctype>
#include <chrono>
#include <thread>

MonitorClient::MonitorClient()
{
    WSADATA data{};
    wsaReady_ = WSAStartup(MAKEWORD(2, 2), &data) == 0;
}

MonitorClient::~MonitorClient()
{
    Disconnect();
    if(wsaReady_) WSACleanup();
}

void MonitorClient::Disconnect()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if(socket_ != INVALID_SOCKET) {
        shutdown(socket_, SD_BOTH);
        closesocket(socket_);
        socket_ = INVALID_SOCKET;
    }
}

bool MonitorClient::Connect(const std::string& host, int port, int retries, int retryDelayMs)
{
    if(!wsaReady_) return false;
    for(int attempt = 0; attempt < retries; ++attempt) {
        SOCKET s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if(s == INVALID_SOCKET) return false;

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(static_cast<u_short>(port));
        inet_pton(AF_INET, host.c_str(), &addr.sin_addr);

        if(connect(s, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == 0) {
            socket_ = s;
            DWORD timeout = 25;
            setsockopt(socket_, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char*>(&timeout), sizeof(timeout));
            std::this_thread::sleep_for(std::chrono::milliseconds(80));
            Drain();
            return true;
        }
        closesocket(s);
        std::this_thread::sleep_for(std::chrono::milliseconds(retryDelayMs));
    }
    return false;
}

void MonitorClient::Drain()
{
    if(socket_ == INVALID_SOCKET) return;
    u_long nonBlocking = 1;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);
    char buf[2048];
    while(recv(socket_, buf, sizeof(buf), 0) > 0) {}
    nonBlocking = 0;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);
}

std::string MonitorClient::ReadAvailable(int firstWaitMs, int idleMs)
{
    std::this_thread::sleep_for(std::chrono::milliseconds(firstWaitMs));
    std::string out;
    char buf[4096];
    bool gotAny = false;
    auto lastData = std::chrono::steady_clock::now();
    const auto deadline = lastData + std::chrono::milliseconds(80);

    u_long nonBlocking = 1;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);
    while(std::chrono::steady_clock::now() < deadline) {
        int n = recv(socket_, buf, sizeof(buf), 0);
        if(n > 0) {
            out.append(buf, buf + n);
            gotAny = true;
            lastData = std::chrono::steady_clock::now();
            continue;
        }
        if(n == 0) break;

        const int err = WSAGetLastError();
        if(err != WSAEWOULDBLOCK) break;
        const auto now = std::chrono::steady_clock::now();
        if(gotAny && std::chrono::duration_cast<std::chrono::milliseconds>(now - lastData).count() >= idleMs) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    nonBlocking = 0;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);
    return StripAnsi(out);
}

std::string MonitorClient::StripAnsi(const std::string& s)
{
    std::string out;
    bool esc = false;
    for(size_t i = 0; i < s.size(); ++i) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if(!esc && c == 0x1B) { esc = true; continue; }
        if(esc) {
            if((c >= '@' && c <= '~')) esc = false;
            continue;
        }
        if(c == '\r' || c == '\n' || c == '\t' || (c >= 32 && c < 127)) out.push_back(static_cast<char>(c));
    }
    return out;
}

bool MonitorClient::Execute(const std::string& command, std::string* response)
{
    std::lock_guard<std::mutex> lock(mutex_);
    if(socket_ == INVALID_SOCKET) return false;
    Drain();
    const std::string line = command + "\r\n";
    int sent = send(socket_, line.data(), static_cast<int>(line.size()), 0);
    if(sent != static_cast<int>(line.size())) return false;
    std::string r = ReadAvailable();
    if(response) *response = std::move(r);
    return true;
}

bool MonitorClient::QueryBool(const std::string& command, bool& value)
{
    std::string r;
    if(!Execute(command, &r)) return false;
    std::transform(r.begin(), r.end(), r.begin(), [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
    auto t = r.find("true");
    auto f = r.find("false");
    if(t == std::string::npos && f == std::string::npos) return false;
    if(t != std::string::npos && (f == std::string::npos || t > f)) { value = true; return true; }
    value = false;
    return true;
}

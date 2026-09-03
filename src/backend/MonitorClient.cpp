#include "backend/MonitorClient.h"
#include <windows.h>
#include <algorithm>
#include <cctype>
#include <chrono>
#include <thread>

namespace {
constexpr unsigned char IAC  = 255;
constexpr unsigned char DONT = 254;
constexpr unsigned char DO   = 253;
constexpr unsigned char WONT = 252;
constexpr unsigned char WILL = 251;
constexpr unsigned char SB   = 250;
constexpr unsigned char SE   = 240;

constexpr unsigned char OPT_BINARY = 0;
constexpr unsigned char OPT_ECHO = 1;
constexpr unsigned char OPT_SUPPRESS_GO_AHEAD = 3;

bool SupportedTelnetOption(unsigned char option)
{
    return option == OPT_BINARY ||
           option == OPT_ECHO ||
           option == OPT_SUPPRESS_GO_AHEAD;
}
}

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

void MonitorClient::ResetTelnetState()
{
    telnetState_ = TelnetState::Data;
    telnetCommand_ = 0;
}

void MonitorClient::Disconnect()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if(socket_ != INVALID_SOCKET) {
        shutdown(socket_, SD_BOTH);
        closesocket(socket_);
        socket_ = INVALID_SOCKET;
    }
    ResetTelnetState();
}

void MonitorClient::ReplyTelnetOption(unsigned char command, unsigned char option)
{
    if(socket_ == INVALID_SOCKET) return;

    const bool supported = SupportedTelnetOption(option);
    unsigned char reply = WONT;

    switch(command) {
        case DO:
            reply = supported ? WILL : WONT;
            break;
        case DONT:
            reply = WONT;
            break;
        case WILL:
            reply = supported ? DO : DONT;
            break;
        case WONT:
            reply = DONT;
            break;
        default:
            return;
    }

    const char response[3] = {
        static_cast<char>(IAC),
        static_cast<char>(reply),
        static_cast<char>(option)
    };
    send(socket_, response, 3, 0);
}

void MonitorClient::ProcessTelnetBytes(const char* data, int size, std::string& text)
{
    for(int i = 0; i < size; ++i) {
        const auto b = static_cast<unsigned char>(data[i]);

        switch(telnetState_) {
            case TelnetState::Data:
                if(b == IAC) {
                    telnetState_ = TelnetState::Iac;
                } else {
                    text.push_back(static_cast<char>(b));
                }
                break;

            case TelnetState::Iac:
                if(b == IAC) {
                    text.push_back(static_cast<char>(IAC));
                    telnetState_ = TelnetState::Data;
                } else if(b == DO || b == DONT || b == WILL || b == WONT) {
                    telnetCommand_ = b;
                    telnetState_ = TelnetState::Option;
                } else if(b == SB) {
                    telnetState_ = TelnetState::Subnegotiation;
                } else {
                    telnetState_ = TelnetState::Data;
                }
                break;

            case TelnetState::Option:
                ReplyTelnetOption(telnetCommand_, b);
                telnetCommand_ = 0;
                telnetState_ = TelnetState::Data;
                break;

            case TelnetState::Subnegotiation:
                if(b == IAC) telnetState_ = TelnetState::SubnegotiationIac;
                break;

            case TelnetState::SubnegotiationIac:
                if(b == SE) {
                    telnetState_ = TelnetState::Data;
                } else if(b != IAC) {
                    telnetState_ = TelnetState::Subnegotiation;
                }
                break;
        }
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
            ResetTelnetState();

            // Renode -P exposes a Telnet Monitor. Read/answer its IAC
            // negotiation before treating it as a line-oriented console.
            const std::string greeting = ReadAvailable(80, 10, 1200);
            if(!greeting.empty()) {
                return true;
            }

            shutdown(socket_, SD_BOTH);
            closesocket(socket_);
            socket_ = INVALID_SOCKET;
            ResetTelnetState();
        } else {
            closesocket(s);
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(retryDelayMs));
    }
    return false;
}

void MonitorClient::Drain()
{
    if(socket_ == INVALID_SOCKET) return;
    (void)ReadAvailable(0, 2, 30);
}

std::string MonitorClient::ReadAvailable(int firstWaitMs, int idleMs, int maxWaitMs)
{
    if(socket_ == INVALID_SOCKET) return {};

    if(firstWaitMs > 0)
        std::this_thread::sleep_for(std::chrono::milliseconds(firstWaitMs));

    std::string out;
    char buf[4096];
    bool gotAny = false;
    auto started = std::chrono::steady_clock::now();
    auto lastData = started;

    u_long nonBlocking = 1;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);

    while(true) {
        int n = recv(socket_, buf, sizeof(buf), 0);
        if(n > 0) {
            ProcessTelnetBytes(buf, n, out);
            gotAny = true;
            lastData = std::chrono::steady_clock::now();
            continue;
        }

        if(n == 0) break;

        const int err = WSAGetLastError();
        if(err != WSAEWOULDBLOCK) break;

        const auto now = std::chrono::steady_clock::now();
        const auto elapsed =
            std::chrono::duration_cast<std::chrono::milliseconds>(now - started).count();
        const auto idle =
            std::chrono::duration_cast<std::chrono::milliseconds>(now - lastData).count();

        if(gotAny && idle >= idleMs) break;
        if(elapsed >= maxWaitMs) break;

        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    nonBlocking = 0;
    ioctlsocket(socket_, FIONBIO, &nonBlocking);
    return StripAnsi(out);
}

std::string MonitorClient::StripAnsi(const std::string& s)
{
    std::string out;
    enum class State { Normal, Esc, Csi } state = State::Normal;

    for(unsigned char c : s) {
        switch(state) {
            case State::Normal:
                if(c == 0x1B) {
                    state = State::Esc;
                } else if(c == '\r' || c == '\n' || c == '\t' || (c >= 32 && c < 127)) {
                    out.push_back(static_cast<char>(c));
                }
                break;

            case State::Esc:
                if(c == '[') state = State::Csi;
                else state = State::Normal;
                break;

            case State::Csi:
                if(c >= '@' && c <= '~') state = State::Normal;
                break;
        }
    }
    return out;
}

bool MonitorClient::Execute(const std::string& command, std::string* response)
{
    std::lock_guard<std::mutex> lock(mutex_);
    if(socket_ == INVALID_SOCKET) return false;

    Drain();

    const std::string line = command + "\r\n";
    int totalSent = 0;
    while(totalSent < static_cast<int>(line.size())) {
        const int sent = send(socket_,
                              line.data() + totalSent,
                              static_cast<int>(line.size()) - totalSent,
                              0);
        if(sent <= 0) return false;
        totalSent += sent;
    }

    std::string r = ReadAvailable(8, 6, 350);
    if(response) *response = std::move(r);
    return true;
}

bool MonitorClient::QueryBool(const std::string& command, bool& value)
{
    std::string r;
    if(!Execute(command, &r)) return false;

    std::transform(r.begin(), r.end(), r.begin(),
                   [](unsigned char c){ return static_cast<char>(std::tolower(c)); });

    const auto t = r.rfind("true");
    const auto f = r.rfind("false");

    if(t == std::string::npos && f == std::string::npos) return false;
    if(t != std::string::npos && (f == std::string::npos || t > f)) {
        value = true;
        return true;
    }

    value = false;
    return true;
}

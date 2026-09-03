#pragma once
#include <winsock2.h>
#include <ws2tcpip.h>
#include <string>
#include <mutex>

class MonitorClient {
public:
    MonitorClient();
    ~MonitorClient();

    bool Connect(const std::string& host, int port, int retries = 80, int retryDelayMs = 100);
    void Disconnect();
    bool IsConnected() const { return socket_ != INVALID_SOCKET; }

    bool Execute(const std::string& command, std::string* response = nullptr);
    bool QueryBool(const std::string& command, bool& value);

private:
    enum class TelnetState {
        Data,
        Iac,
        Option,
        Subnegotiation,
        SubnegotiationIac
    };

    void Drain();
    std::string ReadAvailable(int firstWaitMs = 8, int idleMs = 5, int maxWaitMs = 250);
    void ProcessTelnetBytes(const char* data, int size, std::string& text);
    void ReplyTelnetOption(unsigned char command, unsigned char option);
    void ResetTelnetState();
    static std::string StripAnsi(const std::string& s);

    SOCKET socket_ = INVALID_SOCKET;
    bool wsaReady_ = false;
    std::mutex mutex_;

    TelnetState telnetState_ = TelnetState::Data;
    unsigned char telnetCommand_ = 0;
};

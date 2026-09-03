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
    void Drain();
    std::string ReadAvailable(int firstWaitMs = 4, int idleMs = 3);
    static std::string StripAnsi(const std::string& s);

    SOCKET socket_ = INVALID_SOCKET;
    bool wsaReady_ = false;
    std::mutex mutex_;
};

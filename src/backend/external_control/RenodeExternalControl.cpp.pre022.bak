#include "backend/external_control/RenodeExternalControl.h"

#include <winsock2.h>
#include <ws2tcpip.h>

#include <algorithm>
#include <chrono>
#include <cstring>
#include <string_view>
#include <vector>

namespace {

constexpr std::uint8_t kCmdGetMachine = 3;
constexpr std::uint8_t kCmdGpio = 5;

constexpr std::uint8_t kRcCommandFailed = 0;
constexpr std::uint8_t kRcFatalError = 1;
constexpr std::uint8_t kRcInvalidCommand = 2;
constexpr std::uint8_t kRcSuccessWithData = 3;
constexpr std::uint8_t kRcSuccessWithoutData = 4;
constexpr std::uint8_t kRcSuccessHandshake = 5;
constexpr std::uint8_t kRcAsyncEvent = 6;

using Bytes = std::vector<std::uint8_t>;

void AppendU16(Bytes& out, std::uint16_t value)
{
    out.push_back(static_cast<std::uint8_t>(value & 0xFFu));
    out.push_back(static_cast<std::uint8_t>((value >> 8) & 0xFFu));
}

void AppendU32(Bytes& out, std::uint32_t value)
{
    for(int shift = 0; shift < 32; shift += 8) {
        out.push_back(static_cast<std::uint8_t>((value >> shift) & 0xFFu));
    }
}

void AppendI32(Bytes& out, std::int32_t value)
{
    AppendU32(out, static_cast<std::uint32_t>(value));
}

std::uint32_t ReadU32(const std::uint8_t* p)
{
    return static_cast<std::uint32_t>(p[0]) |
           (static_cast<std::uint32_t>(p[1]) << 8) |
           (static_cast<std::uint32_t>(p[2]) << 16) |
           (static_cast<std::uint32_t>(p[3]) << 24);
}

std::int32_t ReadI32(const std::uint8_t* p)
{
    return static_cast<std::int32_t>(ReadU32(p));
}

bool SendAll(SOCKET socket, const std::uint8_t* data, std::size_t size)
{
    std::size_t sent = 0;
    while(sent < size) {
        const int chunk = send(socket,
                               reinterpret_cast<const char*>(data + sent),
                               static_cast<int>(size - sent),
                               0);
        if(chunk <= 0) return false;
        sent += static_cast<std::size_t>(chunk);
    }
    return true;
}

bool ReceiveExact(SOCKET socket, std::uint8_t* data, std::size_t size)
{
    std::size_t received = 0;
    while(received < size) {
        const int chunk = recv(socket,
                               reinterpret_cast<char*>(data + received),
                               static_cast<int>(size - received),
                               0);
        if(chunk <= 0) return false;
        received += static_cast<std::size_t>(chunk);
    }
    return true;
}

bool ReceiveDiscard(SOCKET socket, std::uint32_t size)
{
    std::array<std::uint8_t, 256> scratch{};
    while(size > 0) {
        const auto chunk = static_cast<std::size_t>(
            std::min<std::uint32_t>(size, static_cast<std::uint32_t>(scratch.size()))
        );
        if(!ReceiveExact(socket, scratch.data(), chunk)) return false;
        size -= static_cast<std::uint32_t>(chunk);
    }
    return true;
}

bool ReadResponse(SOCKET socket,
                  std::uint8_t expectedCommand,
                  Bytes& response)
{
    response.clear();

    for(;;) {
        std::uint8_t rc = 0;
        if(!ReceiveExact(socket, &rc, 1)) return false;

        if(rc == kRcAsyncEvent) {
            // No callbacks are registered in Patch 021, but consume an event
            // defensively so a future Renode version cannot desynchronize us.
            std::uint8_t eventCommand = 0;
            std::array<std::uint8_t, 8> eventHeader{};
            if(!ReceiveExact(socket, &eventCommand, 1)) return false;
            if(!ReceiveExact(socket, eventHeader.data(), eventHeader.size())) return false;
            const auto payloadLength = ReadU32(eventHeader.data() + 4);
            if(!ReceiveDiscard(socket, payloadLength)) return false;
            continue;
        }

        if(rc == kRcFatalError) {
            std::array<std::uint8_t, 4> lenBytes{};
            if(!ReceiveExact(socket, lenBytes.data(), lenBytes.size())) return false;
            return ReceiveDiscard(socket, ReadU32(lenBytes.data())) && false;
        }

        std::uint8_t returnedCommand = 0;
        if(rc == kRcCommandFailed ||
           rc == kRcInvalidCommand ||
           rc == kRcSuccessWithData ||
           rc == kRcSuccessWithoutData) {
            if(!ReceiveExact(socket, &returnedCommand, 1)) return false;
        }

        if(returnedCommand != expectedCommand) return false;

        if(rc == kRcCommandFailed) {
            std::array<std::uint8_t, 4> lenBytes{};
            if(!ReceiveExact(socket, lenBytes.data(), lenBytes.size())) return false;
            return ReceiveDiscard(socket, ReadU32(lenBytes.data())) && false;
        }

        if(rc == kRcInvalidCommand) return false;

        if(rc == kRcSuccessWithoutData) return true;

        if(rc == kRcSuccessWithData) {
            std::array<std::uint8_t, 4> lenBytes{};
            if(!ReceiveExact(socket, lenBytes.data(), lenBytes.size())) return false;

            const auto length = ReadU32(lenBytes.data());
            response.resize(length);
            return length == 0 || ReceiveExact(socket, response.data(), response.size());
        }

        return false;
    }
}

bool InvokeCommand(SOCKET socket,
                   std::uint8_t command,
                   const Bytes& payload,
                   Bytes& response)
{
    Bytes frame;
    frame.reserve(7 + payload.size());
    frame.push_back(0x52); // R
    frame.push_back(0x45); // E
    frame.push_back(command);
    AppendU32(frame, static_cast<std::uint32_t>(payload.size()));
    frame.insert(frame.end(), payload.begin(), payload.end());

    return SendAll(socket, frame.data(), frame.size()) &&
           ReadResponse(socket, command, response);
}

bool PerformHandshake(SOCKET socket)
{
    // Renode 1.16.1 command_versions:
    // RUN_FOR v0, GET_TIME v0, GET_MACHINE v0, ADC v0, GPIO v1, SYSTEM_BUS v0.
    Bytes hello;
    AppendU16(hello, 6);
    const std::array<std::array<std::uint8_t, 2>, 6> versions{{
        {{1, 0}}, {{2, 0}}, {{3, 0}},
        {{4, 0}}, {{5, 1}}, {{6, 0}}
    }};
    for(const auto& pair : versions) {
        hello.push_back(pair[0]);
        hello.push_back(pair[1]);
    }

    if(!SendAll(socket, hello.data(), hello.size())) return false;

    std::uint8_t rc = 0;
    return ReceiveExact(socket, &rc, 1) && rc == kRcSuccessHandshake;
}

bool GetMachineDescriptor(SOCKET socket,
                          std::string_view machineName,
                          std::int32_t& descriptor)
{
    Bytes payload;
    AppendU32(payload, static_cast<std::uint32_t>(machineName.size()));
    payload.insert(payload.end(), machineName.begin(), machineName.end());

    Bytes response;
    if(!InvokeCommand(socket, kCmdGetMachine, payload, response) ||
       response.size() != 4) {
        return false;
    }

    descriptor = ReadI32(response.data());
    return true;
}

bool GetGpioDescriptor(SOCKET socket,
                       std::int32_t machineDescriptor,
                       std::string_view gpioName,
                       std::int32_t& descriptor)
{
    Bytes payload;
    AppendI32(payload, -1);
    AppendI32(payload, machineDescriptor);
    AppendI32(payload, static_cast<std::int32_t>(gpioName.size()));
    payload.insert(payload.end(), gpioName.begin(), gpioName.end());

    Bytes response;
    if(!InvokeCommand(socket, kCmdGpio, payload, response) ||
       response.size() != 4) {
        return false;
    }

    descriptor = ReadI32(response.data());
    return true;
}

bool GetGpioState(SOCKET socket,
                  std::int32_t gpioDescriptor,
                  std::int32_t pin,
                  bool& state)
{
    // gpio_frame.out prefix:
    // int32 gpio_id, uint8 GET_STATE(0), int32 pin
    Bytes payload;
    AppendI32(payload, gpioDescriptor);
    payload.push_back(0);
    AppendI32(payload, pin);

    Bytes response;
    if(!InvokeCommand(socket, kCmdGpio, payload, response) ||
       response.size() != 1) {
        return false;
    }

    state = response[0] != 0;
    return true;
}

SOCKET ConnectSocket(const std::string& host, std::uint16_t port)
{
    SOCKET socketHandle = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if(socketHandle == INVALID_SOCKET) return INVALID_SOCKET;

    DWORD timeoutMs = 750;
    setsockopt(socketHandle, SOL_SOCKET, SO_RCVTIMEO,
               reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));
    setsockopt(socketHandle, SOL_SOCKET, SO_SNDTIMEO,
               reinterpret_cast<const char*>(&timeoutMs), sizeof(timeoutMs));

    BOOL noDelay = TRUE;
    setsockopt(socketHandle, IPPROTO_TCP, TCP_NODELAY,
               reinterpret_cast<const char*>(&noDelay), sizeof(noDelay));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_port = htons(port);

    if(inet_pton(AF_INET, host.c_str(), &address.sin_addr) != 1) {
        closesocket(socketHandle);
        return INVALID_SOCKET;
    }

    if(connect(socketHandle,
               reinterpret_cast<const sockaddr*>(&address),
               sizeof(address)) == SOCKET_ERROR) {
        closesocket(socketHandle);
        return INVALID_SOCKET;
    }

    return socketHandle;
}

} // namespace

RenodeExternalControl::RenodeExternalControl()
{
    for(auto& state : gpioBMirrorStates_) state.store(false);
}

RenodeExternalControl::~RenodeExternalControl()
{
    Stop();
}

void RenodeExternalControl::Start(std::string host,
                                  std::uint16_t port,
                                  std::string machineName)
{
    Stop();

    host_ = std::move(host);
    port_ = port;
    machineName_ = std::move(machineName);

    stopRequested_.store(false);
    connected_.store(false);
    for(auto& state : gpioBMirrorStates_) state.store(false);

    worker_ = std::thread(&RenodeExternalControl::WorkerMain, this);
}

void RenodeExternalControl::Stop()
{
    stopRequested_.store(true);

    if(worker_.joinable()) {
        worker_.join();
    }

    connected_.store(false);
}

bool RenodeExternalControl::IsConnected() const noexcept
{
    return connected_.load();
}

bool RenodeExternalControl::TryRead(const char* controller,
                                    int pin,
                                    bool& state) const noexcept
{
    if(!controller || std::strcmp(controller, "gpioPortB") != 0) return false;
    if(pin < 0 || pin >= static_cast<int>(gpioBMirrorStates_.size())) return false;
    if(!connected_.load()) return false;

    state = gpioBMirrorStates_[static_cast<std::size_t>(pin)].load();
    return true;
}

void RenodeExternalControl::WorkerMain()
{
    WSADATA wsa{};
    if(WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
        connected_.store(false);
        return;
    }

    while(!stopRequested_.load()) {
        SOCKET socketHandle = ConnectSocket(host_, port_);
        if(socketHandle == INVALID_SOCKET) {
            std::this_thread::sleep_for(std::chrono::milliseconds(150));
            continue;
        }

        std::int32_t machineDescriptor = -1;
        std::int32_t gpioBDescriptor = -1;

        const bool initialized =
            PerformHandshake(socketHandle) &&
            GetMachineDescriptor(socketHandle, machineName_, machineDescriptor) &&
            GetGpioDescriptor(socketHandle, machineDescriptor,
                              "gpioPortB", gpioBDescriptor);

        if(!initialized) {
            closesocket(socketHandle);
            connected_.store(false);
            std::this_thread::sleep_for(std::chrono::milliseconds(150));
            continue;
        }

        connected_.store(true);

        bool connectionHealthy = true;
        while(!stopRequested_.load() && connectionHealthy) {
            for(int pin = 0; pin < 4; ++pin) {
                bool state = false;
                if(!GetGpioState(socketHandle, gpioBDescriptor, pin, state)) {
                    connectionHealthy = false;
                    break;
                }
                gpioBMirrorStates_[static_cast<std::size_t>(pin)].store(state);
            }

            if(connectionHealthy) {
                // Network work stays on this thread. SDL only reads atomics.
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
            }
        }

        connected_.store(false);
        shutdown(socketHandle, SD_BOTH);
        closesocket(socketHandle);

        if(!stopRequested_.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    }

    WSACleanup();
}

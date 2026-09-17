#include <librobot/librobot.h>

#include <QCoreApplication>
#include <QHostAddress>
#include <QNetworkDatagram>
#include <QUdpSocket>

#include <array>
#include <chrono>
#include <condition_variable>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

namespace {
using namespace std::chrono_literals;

QByteArray basicSensorPacket() {
  std::array<unsigned char, 32> packet{
      0x1A, 0x01, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x04, 0x07, 0x01, 0x02, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x10, 0x78, 0x56, 0x34, 0x12};
  return QByteArray(reinterpret_cast<const char *>(packet.data()),
                    static_cast<int>(packet.size()));
}

QByteArray translationCommand(int millimetresPerSecond) {
  std::array<unsigned char, 14> command{
      0xAA, 0x55, 0x0A, 0x0C, 0x02, 0xF0, 0x00,
      0x01, 0x04,
      static_cast<unsigned char>(millimetresPerSecond % 256),
      static_cast<unsigned char>(millimetresPerSecond >> 8), 0x00, 0x00, 0x00};
  for (std::size_t index = 2; index < 13; ++index) {
    command[13] ^= command[index];
  }
  return QByteArray(reinterpret_cast<const char *>(command.data()),
                    static_cast<int>(command.size()));
}

bool waitForDatagram(QUdpSocket &socket, std::chrono::milliseconds timeout) {
  return socket.hasPendingDatagrams() ||
         socket.waitForReadyRead(static_cast<int>(timeout.count()));
}

bool takeExpectedDatagram(QUdpSocket &socket, const QByteArray &expected,
                          std::chrono::milliseconds timeout) {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (std::chrono::steady_clock::now() < deadline) {
    const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
        deadline - std::chrono::steady_clock::now());
    if (!waitForDatagram(socket, remaining)) {
      return false;
    }
    while (socket.hasPendingDatagrams()) {
      if (socket.receiveDatagram().data() == expected) {
        return true;
      }
    }
  }
  return false;
}
} // namespace

int main(int argc, char **argv) {
  QCoreApplication application(argc, argv);
  QUdpSocket robotCommandReceiver;
  QUdpSocket laserCommandReceiver;
  QUdpSocket sensorSender;
  if (!robotCommandReceiver.bind(QHostAddress::LocalHost, 0) ||
      !laserCommandReceiver.bind(QHostAddress::LocalHost, 0)) {
    std::cerr << "Could not bind localhost fixture sockets.\n";
    return 1;
  }

  std::mutex callbackMutex;
  std::condition_variable callbackArrived;
  bool callbackCalled = false;
  std::thread::id callbackThread;
  libRobot *activeRobot = nullptr;
  std::function<int(const std::vector<LaserData> &)> laserCallback =
      [](const std::vector<LaserData> &) { return 0; };
  std::function<int(const TKobukiData &)> robotCallback =
      [&](const TKobukiData &) {
        activeRobot->setTranslationSpeed(321);
        {
          std::lock_guard lock{callbackMutex};
          callbackThread = std::this_thread::get_id();
          callbackCalled = true;
        }
        callbackArrived.notify_one();
        return 0;
      };

  auto robot = std::make_unique<libRobot>(
      laserCallback, robotCallback, "127.0.0.1", 0,
      laserCommandReceiver.localPort(), "127.0.0.1", 0,
      robotCommandReceiver.localPort());
  activeRobot = robot.get();
  robot->robotStart();

  if (!waitForDatagram(robotCommandReceiver, 2s)) {
    std::cerr << "Robot worker did not initialize its localhost socket.\n";
    return 1;
  }
  const quint16 robotInputPort =
      robotCommandReceiver.receiveDatagram().senderPort();
  if (robotInputPort == 0) {
    std::cerr << "Robot worker did not expose its localhost input port.\n";
    return 1;
  }
  while (robotCommandReceiver.hasPendingDatagrams()) {
    robotCommandReceiver.receiveDatagram();
  }

  robot->setTranslationSpeed(123);
  if (!takeExpectedDatagram(robotCommandReceiver, translationCommand(123), 2s)) {
    std::cerr << "Caller-issued command was not sent by the robot worker.\n";
    return 1;
  }

  QByteArray sensorPacket = basicSensorPacket();
  TKobukiData parsedSensor{};
  CKobuki packetParser;
  if (packetParser.fillData(
          parsedSensor,
          reinterpret_cast<unsigned char *>(sensorPacket.data())) != 0) {
    std::cerr << "The localhost sensor fixture is not a valid Kobuki packet.\n";
    return 1;
  }
  if (sensorSender.writeDatagram(sensorPacket, QHostAddress::LocalHost,
                                 robotInputPort) == -1) {
    std::cerr << "Could not inject the localhost sensor datagram.\n";
    return 1;
  }

  {
    std::unique_lock lock{callbackMutex};
    if (!callbackArrived.wait_for(lock, 2s, [&] { return callbackCalled; })) {
      std::cerr << "Robot callback was not invoked.\n";
      return 1;
    }
  }
  if (callbackThread == std::this_thread::get_id()) {
    std::cerr << "Robot callback ran on the caller thread.\n";
    return 1;
  }

  const QByteArray expectedCommand = translationCommand(321);
  if (!takeExpectedDatagram(robotCommandReceiver, expectedCommand, 2s)) {
    std::cerr << "Callback-issued command was not sent by the robot worker.\n";
    return 1;
  }

  const auto destructionStarted = std::chrono::steady_clock::now();
  robot.reset();
  activeRobot = nullptr;
  const auto destructionElapsed = std::chrono::steady_clock::now() -
                                  destructionStarted;
  if (destructionElapsed > 2s) {
    std::cerr << "Worker shutdown exceeded the two-second test bound.\n";
    return 1;
  }
  return 0;
}

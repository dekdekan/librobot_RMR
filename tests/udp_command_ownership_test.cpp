#include <librobot/udp_communication.h>

#include <QCoreApplication>
#include <QHostAddress>
#include <QNetworkDatagram>
#include <QUdpSocket>

#include <chrono>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

int main(int argc, char **argv) {
  QCoreApplication application(argc, argv);
  QUdpSocket receiver;
  if (!receiver.bind(QHostAddress::LocalHost, 0)) {
    std::cerr << "Could not bind the localhost command receiver.\n";
    return 1;
  }
  const quint16 destinationPort = receiver.localPort();

  udp_communication communication;
  std::mutex stateMutex;
  std::condition_variable stateChanged;
  bool workerReady = false;
  bool allowDrain = false;

  std::thread worker([&] {
    communication.init_connection("127.0.0.1", destinationPort, 0);
    {
      std::lock_guard lock{stateMutex};
      workerReady = true;
    }
    stateChanged.notify_one();

    {
      std::unique_lock lock{stateMutex};
      stateChanged.wait(lock, [&] { return allowDrain; });
    }
    char ignored = 0;
    communication.getMessage(&ignored, sizeof(ignored));
    communication.deinit_connection();
  });

  {
    std::unique_lock lock{stateMutex};
    if (!stateChanged.wait_for(lock, std::chrono::seconds(2),
                               [&] { return workerReady; })) {
      allowDrain = true;
      lock.unlock();
      stateChanged.notify_one();
      worker.join();
      std::cerr << "UDP worker did not initialize.\n";
      return 1;
    }
  }

  const std::vector<std::vector<unsigned char>> commands{
      {0xAA, 0x55, 0x01, 0xFE}, {0xAA, 0x55, 0x02, 0xFD}};
  for (const auto &command : commands) {
    communication.sendMessage(command);
  }
  const bool sentFromCallerThread = receiver.waitForReadyRead(150);
  while (receiver.hasPendingDatagrams()) {
    receiver.receiveDatagram();
  }

  {
    std::lock_guard lock{stateMutex};
    allowDrain = true;
  }
  stateChanged.notify_one();

  std::vector<QByteArray> received;
  for (std::size_t index = 0; index < commands.size(); ++index) {
    if (!receiver.waitForReadyRead(1000) && !receiver.hasPendingDatagrams()) {
      break;
    }
    received.push_back(receiver.receiveDatagram().data());
  }
  worker.join();

  if (sentFromCallerThread) {
    std::cerr << "Command touched the worker-owned socket from the caller thread.\n";
    return 1;
  }
  if (received.size() != commands.size()) {
    std::cerr << "Worker did not send every queued command.\n";
    return 1;
  }
  for (std::size_t index = 0; index < commands.size(); ++index) {
    const QByteArray expected(
        reinterpret_cast<const char *>(commands[index].data()),
        static_cast<int>(commands[index].size()));
    if (received[index] != expected) {
      std::cerr << "Worker did not preserve queued command order.\n";
      return 1;
    }
  }
  return 0;
}

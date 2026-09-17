#include "librobot/udp_communication.h"
#include <QByteArray>
#include <algorithm>
#include <cstring>

udp_communication::udp_communication() = default;

udp_communication::~udp_communication() { deinit_connection(); }

void udp_communication::deinit_connection() {
  if (socket) {
    socket->close();
    delete socket;
    socket = nullptr;
  }
  std::lock_guard lock{pendingMessagesMutex};
  ownerThread = {};
}

void udp_communication::init_connection(const std::string &address, int inport,
                                        int outport) {
  destAddress = QHostAddress(QString::fromStdString(address));
  destPort = static_cast<quint16>(inport);
  if (!socket)
    socket = new QUdpSocket(); // created inside the worker thread
  static_cast<void>(
      socket->bind(QHostAddress::Any, static_cast<quint16>(outport)));
  {
    std::lock_guard lock{pendingMessagesMutex};
    ownerThread = std::this_thread::get_id();
  }

  // getMessage uses a bounded wait so shutdown can join this worker.
}

int udp_communication::sendMessage(const std::vector<unsigned char> &mess) {
  {
    std::lock_guard lock{pendingMessagesMutex};
    if (ownerThread != std::this_thread::get_id()) {
      pendingMessages.push_back(mess);
      return 0;
    }
  }
  sendPendingMessages();
  return sendDatagram(mess);
}

int udp_communication::sendDatagram(
    const std::vector<unsigned char> &message) {
  if (!socket)
    return -1;
  const QByteArray data(reinterpret_cast<const char *>(message.data()),
                        static_cast<int>(message.size()));
  return socket->writeDatagram(data, destAddress, destPort) == -1 ? -1 : 0;
}

int udp_communication::sendPendingMessages() {
  if (!socket)
    return -1;

  std::vector<std::vector<unsigned char>> messages;
  {
    std::lock_guard lock{pendingMessagesMutex};
    messages.swap(pendingMessages);
  }

  int result = 0;
  for (const auto &message : messages) {
    if (sendDatagram(message) == -1)
      result = -1;
  }
  return result;
}

int udp_communication::getMessage(char *message, int maxSize) {
  if (!socket)
    return -1;
  sendPendingMessages();
  if (!socket->waitForReadyRead(500))
    return -1;

  buffer.resize(static_cast<int>(socket->pendingDatagramSize()));
  QHostAddress sender;
  quint16 senderPort;
  qint64 received =
      socket->readDatagram(buffer.data(), buffer.size(), &sender, &senderPort);

  if (received == -1)
    return -1;

  int copySize =
      static_cast<int>(std::min(static_cast<qint64>(maxSize), received));
  memcpy(message, buffer.constData(), copySize);
  return copySize;
}

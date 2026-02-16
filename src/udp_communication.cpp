#include "librobot/udp_communication.h"
#include <QByteArray>
#include <QCoreApplication>
#include <iostream>

udp_communication::udp_communication() {
    socket = nullptr;
}


void udp_communication::deinit_connection()
{
    if (socket) {
        socket->close();
        delete socket;
        socket = nullptr;
    }
}
void udp_communication::init_connection(const std::string &address, int inport, int outport) {
    destAddress = QHostAddress(QString::fromStdString(address));
    destPort = static_cast<quint16>(inport);
    if (!socket)
        socket = new QUdpSocket();   // created INSIDE worker thread
    // Bind local port for receiving
    if (!socket->bind(QHostAddress::Any, static_cast<quint16>(outport))) {
        std::cerr << "UDP bind failed!" << std::endl;
    }

    // Optional: set a read timeout by using waitForReadyRead in getMessage
}

int udp_communication::sendMessage(const std::vector<unsigned char> &mess) {
    QByteArray data(reinterpret_cast<const char *>(mess.data()), static_cast<int>(mess.size()));
    qint64 sent = socket->writeDatagram(data, destAddress, destPort);
    return (sent == -1) ? -1 : 0;
}

int udp_communication::getMessage(char *message, int maxSize) {
    if (!socket->waitForReadyRead(500))   // -1 = infinite wait
        return -1;

    buffer.resize(static_cast<int>(socket->pendingDatagramSize()));
    QHostAddress sender;
    quint16 senderPort;
    qint64 received = socket->readDatagram(buffer.data(), buffer.size(), &sender, &senderPort);

    if (received == -1)
        return -1;

    int copySize = static_cast<int>(std::min(static_cast<qint64>(maxSize), received));
    memcpy(message, buffer.constData(), copySize);
    return copySize;
}

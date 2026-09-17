#ifndef UDP_COMMUNICATION_H
#define UDP_COMMUNICATION_H

#include <QByteArray>
#include <QHostAddress>
#include <QString>
#include <QUdpSocket>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class udp_communication {
public:
    udp_communication();
    ~udp_communication();
    udp_communication(const udp_communication &) = delete;
    udp_communication &operator=(const udp_communication &) = delete;

    void init_connection(const std::string &address, int inport, int outport);
    void deinit_connection();
    int sendMessage(const std::vector<unsigned char> &mess);
    int getMessage(char *message, int maxSize);

private:
    int sendDatagram(const std::vector<unsigned char> &message);
    int sendPendingMessages();

    QUdpSocket *socket{nullptr};
    QHostAddress destAddress;
    quint16 destPort{0};
    QByteArray buffer;
    std::mutex pendingMessagesMutex;
    std::vector<std::vector<unsigned char>> pendingMessages;
    std::thread::id ownerThread;
};

#endif // UDP_COMMUNICATION_H

#ifndef UDP_COMMUNICATION_H
#define UDP_COMMUNICATION_H

#include <QString>
#include <QHostAddress>
#include <QUdpSocket>
#include <vector>

class udp_communication {
public:
    udp_communication();
    

    void init_connection(const std::string &address, int inport, int outport);
    void deinit_connection();
    int sendMessage(const std::vector<unsigned char> &mess);
    int getMessage(char *message, int maxSize);

private:
    QUdpSocket *socket{nullptr};
    QHostAddress destAddress;
    quint16 destPort{0};
    QByteArray buffer;
};

#endif // UDP_COMMUNICATION_H

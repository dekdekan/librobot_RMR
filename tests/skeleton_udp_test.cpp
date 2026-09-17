#include <librobot/librobot.h>

#include <QCoreApplication>
#include <QHostAddress>
#include <QUdpSocket>

#include <chrono>
#include <condition_variable>
#include <functional>
#include <iostream>
#include <mutex>
#include <vector>

#ifndef LIBROBOT_HAS_SKELETON
#error "The skeleton runtime test requires skeleton support."
#endif

#ifdef DISABLE_SKELETON
#error "The skeleton runtime test received conflicting feature definitions."
#endif

namespace {
using namespace std::chrono_literals;
static_assert(sizeof(skeleton) == 1800);
}

int main(int argc, char **argv) {
  QCoreApplication application(argc, argv);

  QUdpSocket portProbe;
  if (!portProbe.bind(QHostAddress::LocalHost, 0)) {
    std::cerr << "Could not reserve a localhost UDP port.\n";
    return 1;
  }
  const quint16 skeletonPort = portProbe.localPort();
  portProbe.close();

  std::mutex callbackMutex;
  std::condition_variable callbackArrived;
  int callbackCount = 0;
  skeleton received{};

  std::function<int(const std::vector<LaserData> &)> laserCallback =
      [](const std::vector<LaserData> &) { return 0; };
  std::function<int(const TKobukiData &)> robotCallback =
      [](const TKobukiData &) { return 0; };
  libRobot robot(laserCallback, robotCallback, "127.0.0.1", 0, 0,
                 "127.0.0.1", 0, 0);
  robot.setSkeletonParameters(
      [&](const skeleton &value) {
        {
          std::lock_guard lock{callbackMutex};
          received = value;
          ++callbackCount;
        }
        callbackArrived.notify_one();
        return 0;
      },
      "127.0.0.1", skeletonPort, 0);
  robot.robotStart();

  QUdpSocket sender;
  skeleton expected{};
  expected.joints[left_wrist].x = 1.25;
  expected.joints[nose].y = -2.5;
  expected.joints[right_foot_index].z = 3.75;
  const QByteArray payload(reinterpret_cast<const char *>(&expected),
                           static_cast<int>(sizeof(expected)));
  const auto deadline = std::chrono::steady_clock::now() + 3s;
  while (std::chrono::steady_clock::now() < deadline) {
    if (sender.writeDatagram(payload, QHostAddress::LocalHost, skeletonPort) < 0) {
      std::cerr << "Could not send the skeleton fixture datagram.\n";
      return 1;
    }
    std::unique_lock lock{callbackMutex};
    if (callbackArrived.wait_for(lock, 50ms, [&] { return callbackCount > 0; })) {
      break;
    }
  }

  int validCallbackCount = 0;
  {
    std::lock_guard lock{callbackMutex};
    if (callbackCount == 0) {
      std::cerr << "Skeleton callback was not invoked.\n";
      return 1;
    }
    if (received.joints[left_wrist].x != expected.joints[left_wrist].x ||
        received.joints[nose].y != expected.joints[nose].y ||
        received.joints[right_foot_index].z !=
            expected.joints[right_foot_index].z) {
      std::cerr << "Skeleton callback received corrupted joint data.\n";
      return 1;
    }
  }
  {
    std::unique_lock lock{callbackMutex};
    int observedCallbackCount = callbackCount;
    const auto settleDeadline = std::chrono::steady_clock::now() + 2s;
    while (std::chrono::steady_clock::now() < settleDeadline &&
           callbackArrived.wait_for(
               lock, 250ms,
               [&] { return callbackCount > observedCallbackCount; })) {
      observedCallbackCount = callbackCount;
    }
    validCallbackCount = callbackCount;
  }

  const auto expectIgnored = [&](const QByteArray &invalidPayload,
                                 const char *errorMessage) {
    const auto invalidDeadline = std::chrono::steady_clock::now() + 500ms;
    while (std::chrono::steady_clock::now() < invalidDeadline) {
      if (sender.writeDatagram(invalidPayload, QHostAddress::LocalHost,
                               skeletonPort) < 0) {
        std::cerr << "Could not send an invalid skeleton datagram.\n";
        return false;
      }
      std::unique_lock lock{callbackMutex};
      if (callbackArrived.wait_for(
              lock, 25ms,
              [&] { return callbackCount > validCallbackCount; })) {
        std::cerr << errorMessage << '\n';
        return false;
      }
    }
    return true;
  };
  if (!expectIgnored(QByteArray(1, '\0'),
                     "Skeleton callback accepted a short datagram.")) {
    return 1;
  }
  if (!expectIgnored(
          QByteArray(static_cast<int>(sizeof(skeleton)) + 1, '\0'),
          "Skeleton callback accepted an oversized datagram.")) {
    return 1;
  }
  return 0;
}

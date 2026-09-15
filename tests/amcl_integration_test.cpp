#include "amcl_adapter.h"

#include <librobot/librobot.h>

#include <QHostAddress>
#include <QUdpSocket>

#include <chrono>
#include <cmath>
#include <filesystem>
#include <functional>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void check(bool condition, const char *expression, int line) {
  if (!condition) {
    std::cerr << "Check failed at line " << line << ": " << expression
              << '\n';
    ++failures;
  }
}

#define CHECK(expression) check((expression), #expression, __LINE__)

std::filesystem::path fixtureMap() {
  return std::filesystem::path{LIBROBOT_TEST_FIXTURE_DIR} / "mapa.txt";
}

void checkPublicLifecycle() {
  libRobot robot;
  const auto callback = [](float, float, float) { return 0; };
  std::string error;

  CHECK(!robot.setAMCLParameters("missing.txt", 100, 0.01, 2.0, callback,
                                 &error));
  CHECK(!error.empty());
  CHECK(robot.setAMCLParameters(fixtureMap(), 100, 0.01, 2.0, callback,
                                &error));
  CHECK(error.empty());
  CHECK(!robot.setAMCLParameters(fixtureMap(), 100, 0.01, 2.0, callback,
                                 &error));
  CHECK(!error.empty());
  CHECK(robot.getAmclMap().width > 0);
}

void checkFailedConfigurationPreventsStart() {
  QUdpSocket portReservation;
  CHECK(portReservation.bind(QHostAddress::LocalHost, 0));
  const int laserPort = portReservation.localPort();
  portReservation.close();
  CHECK(portReservation.bind(QHostAddress::LocalHost, 0));
  const int robotPort = portReservation.localPort();
  portReservation.close();

  std::function<int(const std::vector<LaserData> &)> laserCallback =
      [](const std::vector<LaserData> &) { return 0; };
  std::function<int(const TKobukiData &)> robotCallback =
      [](const TKobukiData &) { return 0; };
  libRobot robot{laserCallback, robotCallback, "127.0.0.1", laserPort, 9,
                 "127.0.0.1", robotPort, 9};
  const auto callback = [](float, float, float) { return 0; };
  std::string error;

  CHECK(!robot.setAMCLParameters("missing.txt", 100, 0.01, 2.0, callback,
                                 &error));
  robot.robotStart();
  std::this_thread::sleep_for(std::chrono::milliseconds{100});

  QUdpSocket laserProbe;
  QUdpSocket robotProbe;
  CHECK(laserProbe.bind(QHostAddress::LocalHost,
                        static_cast<quint16>(laserPort),
                        QUdpSocket::DontShareAddress));
  CHECK(robotProbe.bind(QHostAddress::LocalHost,
                        static_cast<quint16>(robotPort),
                        QUdpSocket::DontShareAddress));

  CHECK(!robot.setAMCLParameters(fixtureMap(), 100, 0.01, 2.0, callback,
                                 &error));
  CHECK(!error.empty());
}

void checkAdapterSnapshotsAndCallback() {
  librobot_detail::AMCLAdapter adapter{42u};
  bool callbackCalled = false;
  float callbackTheta = 0.0F;
  bool snapshotWasReadableInCallback = false;
  std::string error;

  CHECK(adapter.configure(
      fixtureMap(), 100, 0.0, 0.0,
      [&](float, float, float theta) {
        callbackCalled = true;
        callbackTheta = theta;
        const Particle snapshot = adapter.bestParticle();
        snapshotWasReadableInCallback = std::isfinite(snapshot.theta);
        return 0;
      },
      &error));
  CHECK(error.empty());
  CHECK(adapter.map().width == 10);
  CHECK(adapter.map().height == 10);

  adapter.markStarted();
  adapter.updateOdometry(1000, 1000, 0.000085292090497737556558L, 0.23L);
  adapter.updateOdometry(1010, 1020, 0.000085292090497737556558L, 0.23L);

  const std::vector<LaserData> scan{
      {15, 0.0F, 500.0F, 1u},
      {15, 90.0F, 500.0F, 2u},
  };
  adapter.processScan(scan);

  const Particle snapshot = adapter.bestParticle();
  CHECK(std::isfinite(snapshot.x));
  CHECK(std::isfinite(snapshot.y));
  CHECK(std::isfinite(snapshot.theta));
  CHECK(std::isfinite(snapshot.weight));
  CHECK(callbackCalled);
  CHECK(snapshotWasReadableInCallback);
  CHECK(callbackTheta == snapshot.theta);
}

} // namespace

int main() {
  checkPublicLifecycle();
  checkFailedConfigurationPreventsStart();
  checkAdapterSnapshotsAndCallback();
  return failures == 0 ? 0 : 1;
}

#include "librobot/librobot.h"
#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
#include "amcl_adapter.h"
#endif
#include <QThread>
#if defined(LIBROBOT_HAS_OPENCV) && LIBROBOT_HAS_OPENCV
#include <opencv2/videoio.hpp>
#endif
#include <algorithm>
#include <utility>

libRobot::~libRobot() {
  stopRequested_.exchange(true, std::memory_order_acq_rel);
  if (robotthreadHandle.joinable())
    robotthreadHandle.join();
  if (laserthreadHandle.joinable())
    laserthreadHandle.join();
#if defined(LIBROBOT_HAS_OPENCV) && LIBROBOT_HAS_OPENCV
  if (camerathreadhandle.joinable())
    camerathreadhandle.join();
#endif
#ifndef DISABLE_SKELETON
  if (skeletonthreadHandle.joinable())
    skeletonthreadHandle.join();
#endif
}

libRobot::libRobot(
    std::function<int(const std::vector<LaserData> &)> &lascallback,
    std::function<int(const TKobukiData &)> &robcallback,
    std::string ipaddressLaser, int laserportRobot, int laserportMe,
    std::string ipaddressRobot, int robotportRobot, int robotportMe)
    : wasLaserSet(0), wasRobotSet(0), wasCameraSet(0), wasSkeletonSet(0)
#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
      , amclAdapter_(std::make_unique<librobot_detail::AMCLAdapter>())
#endif
{

  setLaserParameters(lascallback, ipaddressLaser, laserportRobot, laserportMe);
  setRobotParameters(robcallback, ipaddressRobot, robotportRobot, robotportMe);
}

/// tato funkcia vas nemusi zaujimat
///  toto je funkcia s nekonecnou sluckou,ktora cita data z robota (UDP
///  komunikacia)
void libRobot::robotprocess() {
  robotCom.init_connection(robot_ipaddress.data(), robot_ip_portIn,
                           robot_ip_portOut);

  std::vector<unsigned char> mess = robot.setDefaultPID();
  robotCom.sendMessage(mess);
  QThread::msleep(100);
  mess = robot.setSound(440, 1000);
  robotCom.sendMessage(mess);
  unsigned char buff[50000];
  while (!stopRequested_.load(std::memory_order_acquire)) {
    memset(buff, 0, 50000 * sizeof(char));
    if (robotCom.getMessage((char *)&buff, sizeof(char) * 50000) == -1)
      continue;
    // https://i.pinimg.com/236x/1b/91/34/1b9134e6a5d2ea2e5447651686f60520--lol-funny-funny-shit.jpg
    // tu mame data..zavolame si funkciu

    int returnval = robot.fillData(sens, (unsigned char *)buff);
    if (returnval == 0) {
      //     memcpy(&sens,buff,sizeof(sens));

#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
      amclAdapter_->updateOdometry(sens.EncoderLeft, sens.EncoderRight,
                                   tickToMeter, b);
#endif

      if (robot_callback)
        robot_callback(sens);
    }
  }

  robotCom.deinit_connection();
}

void libRobot::setTranslationSpeed(int mmpersec) {
  std::vector<unsigned char> mess = robot.setTranslationSpeed(mmpersec);
  robotCom.sendMessage(mess);
}

void libRobot::setRotationSpeed(double radpersec) // left
{

  std::vector<unsigned char> mess = robot.setRotationSpeed(radpersec);
  robotCom.sendMessage(mess);
}

void libRobot::setArcSpeed(int mmpersec, int radius) {
  std::vector<unsigned char> mess = robot.setArcSpeed(mmpersec, radius);
  robotCom.sendMessage(mess);
}

/// tato funkcia vas nemusi zaujimat
///  toto je funkcia s nekonecnou sluckou,ktora cita data z lidaru (UDP
///  komunikacia)
void libRobot::laserprocess() {

  laserCom.init_connection(laser_ipaddress.data(), laser_ip_portIn,
                           laser_ip_portOut);

  std::vector<unsigned char> command = {0x00};
  // najskor posleme prazdny prikaz
  // preco?
  // https://ih0.redbubble.net/image.74126234.5567/raf,750x1000,075,t,heather_grey_lightweight_raglan_sweatshirt.u3.jpg
  laserCom.sendMessage(command);

  LaserMeasurement measure;
  std::vector<LaserData> data;
  int recvlen;
  while (!stopRequested_.load(std::memory_order_acquire)) {
    if ((recvlen = laserCom.getMessage((char *)&measure.Data,
                                       sizeof(LaserData) * 1000)) == -1)
      continue;

    measure.numberOfScans = recvlen / sizeof(LaserData);
    data.resize(measure.numberOfScans);
    std::copy(measure.Data, measure.Data + measure.numberOfScans, data.begin());
    // tu mame data..zavolame si funkciu-- vami definovany callback

#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
    amclAdapter_->processScan(data);
#endif

    
    if (laser_callback)
      laser_callback(data);
    /// ako som vravel,toto vas nemusi zaujimat
  }
  laserCom.deinit_connection();
}

void libRobot::robotStart() {
  {
    std::lock_guard lock{lifecycleMutex_};
    if (robotStarted_) {
      return;
    }
    robotStarted_ = true;
#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
    amclAdapter_->markStarted();
    if (amclConfigurationRequested_ && amclConfigurationFailed_) {
      return;
    }
#endif
  }
  if (wasRobotSet == 1) {
    robotthreadHandle = std::thread(&libRobot::robotprocess, this);
  }
  if (wasLaserSet == 1) {
    laserthreadHandle = std::thread(&libRobot::laserprocess, this);
  }
#if defined(LIBROBOT_HAS_OPENCV) && LIBROBOT_HAS_OPENCV
  if (wasCameraSet == 1) {
    camerathreadhandle = std::thread(&libRobot::imageViewer, this);
  }
#endif
#ifndef DISABLE_SKELETON
  if (wasSkeletonSet == 1) {
    skeletonthreadHandle = std::thread(&libRobot::skeletonprocess, this);
  }
#endif
}

#if defined(LIBROBOT_HAS_AMCL) && LIBROBOT_HAS_AMCL
bool libRobot::setAMCLParameters(const std::filesystem::path &mapPath,
                                 int particleCount, double rotationStd,
                                 double translationStd, AMCLCallback callback,
                                 std::string *errorMessage) {
  std::lock_guard lock{lifecycleMutex_};
  if (errorMessage != nullptr) {
    errorMessage->clear();
  }
  if (robotStarted_) {
    if (errorMessage != nullptr) {
      *errorMessage = "AMCL cannot be configured after robotStart().";
    }
    return false;
  }
  if (amclConfigurationRequested_ && !amclConfigurationFailed_) {
    if (errorMessage != nullptr) {
      *errorMessage = "AMCL has already been configured.";
    }
    return false;
  }

  amclConfigurationRequested_ = true;
  const bool configured =
      amclAdapter_->configure(mapPath, particleCount, rotationStd,
                              translationStd, std::move(callback), errorMessage);
  amclConfigurationFailed_ = !configured;
  return configured;
}

Particle libRobot::getBestParticle() const {
  return amclAdapter_->bestParticle();
}

const GridMap &libRobot::getAmclMap() const { return amclAdapter_->map(); }

void libRobot::getGridCoordinates(double realX, double realY, int &gridX,
                                  int &gridY) const {
  amclAdapter_->worldToGrid(realX, realY, gridX, gridY);
}
#endif

#if defined(LIBROBOT_HAS_OPENCV) && LIBROBOT_HAS_OPENCV
void libRobot::imageViewer() {
  cv::VideoCapture cap;
  if (stopRequested_.load(std::memory_order_acquire))
    return;
  const std::vector<int> captureParameters{
      cv::CAP_PROP_OPEN_TIMEOUT_MSEC, 2000,
      cv::CAP_PROP_READ_TIMEOUT_MSEC, 500};
  if (!cap.open(camera_link, cv::CAP_ANY, captureParameters))
    return;
  cv::Mat frameBuf;
  while (!stopRequested_.load(std::memory_order_acquire)) {
    if (!cap.read(frameBuf)) {
      QThread::msleep(1);
      continue;
    }
    if (camera_callback)
      camera_callback(frameBuf);
  }
  cap.release();
}
#endif

#ifndef DISABLE_SKELETON
void libRobot::skeletonprocess() {

  skeletonCom.init_connection(skeleton_ipaddress, skeleton_ip_portIn,
                              skeleton_ip_portOut);

  skeleton bbbk;
  while (!stopRequested_.load(std::memory_order_acquire)) {
    if (skeletonCom.getMessage((char *)&bbbk.joints, sizeof(char) * 1800) == -1)
      continue;

    if (skeleton_callback)
      skeleton_callback(bbbk);
  }
  skeletonCom.deinit_connection();
}

#endif

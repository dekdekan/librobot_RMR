#include "librobot/librobot.h"
#include <QThread>

libRobot::~libRobot() {

  ready_promise.set_value();
  std::cout<<"bla bla "<<robotthreadHandle.joinable()<<" "<<laserthreadHandle.joinable()<<std::endl;
  if (robotthreadHandle.joinable())
    robotthreadHandle.join();
  if (laserthreadHandle.joinable())
    laserthreadHandle.join();
#ifndef DISABLE_OPENCV
std::cout<<"bla bla2 "<<camerathreadhandle.joinable()<<std::endl;
  if (camerathreadhandle.joinable())
    camerathreadhandle.join();
#endif
#ifndef DISABLE_SKELETON
std::cout<<"bla bla3 "<<skeletonthreadHandle.joinable()<<std::endl;
  if (skeletonthreadHandle.joinable())
    skeletonthreadHandle.join();
#endif
}

libRobot::libRobot(
    std::function<int(const std::vector<LaserData> &)> &lascallback,
    std::function<int(const TKobukiData &)> &robcallback,
    std::string ipaddressLaser, int laserportRobot, int laserportMe,
    std::string ipaddressRobot, int robotportRobot, int robotportMe)
    : wasLaserSet(0), wasRobotSet(0), wasCameraSet(0), wasSkeletonSet(0) {

  setLaserParameters(lascallback, ipaddressLaser, laserportRobot, laserportMe);
  setRobotParameters(robcallback, ipaddressRobot, robotportRobot, robotportMe);
  readyFuture = ready_promise.get_future();
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
  while (1) {

    if (readyFuture.wait_for(std::chrono::seconds(0)) ==
        std::future_status::ready)
      break;
    memset(buff, 0, 50000 * sizeof(char));
    int retlen = robotCom.getMessage((char *)&buff, sizeof(char) * 50000);
    // https://i.pinimg.com/236x/1b/91/34/1b9134e6a5d2ea2e5447651686f60520--lol-funny-funny-shit.jpg
    // tu mame data..zavolame si funkciu

    //     memcpy(&sens,buff,sizeof(sens));
    struct timespec t;
    //      clock_gettime(CLOCK_REALTIME,&t);

    int returnval = robot.fillData(sens, (unsigned char *)buff);
    //   std::cout<<"timestamp robot "<<sens.synctimestamp<<"
    //   "<<sens.EncoderLeft<<std::endl;
    if (returnval == 0) {
      //     memcpy(&sens,buff,sizeof(sens));

      std::chrono::steady_clock::time_point timestampf =
          std::chrono::steady_clock::now();

      ///---toto je callback funkcia...
      std::async(
          std::launch::async,
          [this](TKobukiData sensdata) { robot_callback(sensdata); }, sens);
    }
  }

  robotCom.deinit_connection();
  std::cout << "koniec thread2" << std::endl;
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
  while (1) {

    if (readyFuture.wait_for(std::chrono::seconds(0)) ==
        std::future_status::ready)
      break;
    if ((recvlen = laserCom.getMessage((char *)&measure.Data,
                                       sizeof(LaserData) * 1000)) == -1)
      continue;

    //    std::cout<<"dostal tolkoto "<<recvlen<<std::endl;
    measure.numberOfScans = recvlen / sizeof(LaserData);
    data.resize(measure.numberOfScans);
    std::copy(measure.Data, measure.Data + measure.numberOfScans, data.begin());
    // tu mame data..zavolame si funkciu-- vami definovany callback

    
    std::async(
        std::launch::async,
        [this](const std::vector<LaserData> &sensdata) {
          laser_callback(sensdata);
        },
        data);
    /// ako som vravel,toto vas nemusi zaujimat
  }
  laserCom.deinit_connection();
  std::cout << "koniec thread" << std::endl;
}

void libRobot::robotStart() {
  if (wasRobotSet == 1) {
    std::function<void(void)> f = std::bind(&libRobot::robotprocess, this);
    robotthreadHandle = std::move(std::thread(f));
  }
  if (wasLaserSet == 1) {
    std::function<void(void)> f2 = std::bind(&libRobot::laserprocess, this);
    laserthreadHandle = std::move(std::thread(f2));
  }
#ifndef DISABLE_OPENCV
  if (wasCameraSet == 1) {
    std::function<void(void)> f3 = std::bind(&libRobot::imageViewer, this);
    camerathreadhandle = std::move(std::thread(f3));
  }
#endif
#ifndef DISABLE_SKELETON
  if (wasSkeletonSet == 1) {
    std::function<void(void)> f4 = std::bind(&libRobot::skeletonprocess, this);
    skeletonthreadHandle = std::move(std::thread(f4));
  }
#endif
}

#ifndef DISABLE_OPENCV
void libRobot::imageViewer() {
  cv::VideoCapture cap;
  cap.open(camera_link);
  cv::Mat frameBuf;
  while (1) {

    if (readyFuture.wait_for(std::chrono::seconds(0)) ==
        std::future_status::ready)
      break;
    cap >> frameBuf;

    std::cout << "doslo toto " << frameBuf.rows << " " << frameBuf.cols
              << std::endl;

    // tu sa vola callback..
    std::async(
        std::launch::async,
        [this](cv::Mat camdata) { camera_callback(camdata.clone()); },
        frameBuf);
#ifdef _WIN32
    cv::waitKey(1);
#else
    usleep(1 * 1000);
#endif
  }
  cap.release();
}
#endif

#ifndef DISABLE_SKELETON
void libRobot::skeletonprocess() {

  skeletonCom.init_connection(skeleton_ipaddress, skeleton_ip_portIn,
                              skeleton_ip_portOut);

  char command = 0x00;

  skeleton bbbk;
  double measure[225];
  while (1) {
    if (readyFuture.wait_for(std::chrono::seconds(0)) ==
        std::future_status::ready)
      break;
    if (skeletonCom.getMessage((char *)&bbbk.joints, sizeof(char) * 1800) == -1)
      continue;

    std::async(
        std::launch::async,
        [this](skeleton skele) { skeleton_callback(skele); }, bbbk);
  }
  skeletonCom.deinit_connection();
  std::cout << "koniec thread" << std::endl;
}

#endif
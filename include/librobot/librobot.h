#ifndef LIBROBOT_H
#define LIBROBOT_H
#ifndef DISABLE_OPENCV
#define useCamera
#endif
#ifdef useCamera
#include "opencv2/core/utility.hpp"
#include "opencv2/highgui/highgui.hpp"
#include "opencv2/imgcodecs.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/videoio.hpp"
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>

#endif

#include "CKobuki.h"
#include "robot_global.h"
#include "rplidar.h"
#include "udp_communication.h"
#include <algorithm>
#include <atomic>
#include <functional>
#include <future>
#include <iostream>
#include <list>
#include <memory>
#include <mutex>
#include <random>
#include <thread>
#include <utility>

#include "skeleton.h"
class ROBOT_EXPORT libRobot {
public:
  ~libRobot();
  libRobot(
      std::function<int(const std::vector<LaserData> &)> &lascallback =
          do_nothing_laser,
      std::function<int(const TKobukiData &)> &robcallback = do_nothing_robot,
      std::string ipaddressLaser = "127.0.0.1", int laserportRobot = 52999,
      int laserportMe = 5299, std::string ipaddressRobot = "127.0.0.1",
      int robotportRobot = 53000, int robotportMe = 5300);

  // default functions.. please do not rewrite.. make your own callback
  inline static std::function<int(const TKobukiData &)> do_nothing_robot =
      [](const TKobukiData &data) {
        std::cout << "data z kobuki" << std::endl;
        return 0;
      };

  inline static std::function<int(const std::vector<LaserData> &)>
      do_nothing_laser = [](const std::vector<LaserData> &data) {
        std::cout << "data z rplidar" << std::endl;
        return 0;
      };

  void robotStart();
  void setLaserParameters(
      std::function<int(const std::vector<LaserData> &)> callback,
      std::string ipaddress = "127.0.0.1", int laserportRobot = 52999,
      int laserportMe = 5299) {
    laser_ip_portOut = laserportRobot;
    laser_ip_portIn = laserportMe;
    laser_ipaddress = ipaddress;
    laser_callback = callback;
    wasLaserSet = 1;
  }
  void setRobotParameters(std::function<int(const TKobukiData &)> callback,
                          std::string ipaddress = "127.0.0.1",
                          int robotportRobot = 53000, int robotportMe = 5300) {
    robot_ip_portOut = robotportRobot;
    robot_ip_portIn = robotportMe;
    robot_ipaddress = ipaddress;
    robot_callback = callback;
    wasRobotSet = 1;
  }

  void setTranslationSpeed(int mmpersec);

  void setRotationSpeed(double radpersec);
  void setArcSpeed(int mmpersec, int radius);
#ifndef DISABLE_OPENCV
  void setCameraParameters(std::function<int(const cv::Mat &)> callback,
                           std::string link) {

    camera_link = link;
    camera_callback = callback;
    wasCameraSet = 1;
  }
#endif

#ifndef DISABLE_SKELETON
  void setSkeletonParameters(std::function<int(const skeleton &)> callback,
                             std::string ipaddress = "127.0.0.1",
                             int skeletonportRobot = 23432,
                             int skeletonportMe = 23432) {
    skeleton_ip_portOut = skeletonportRobot;
    skeleton_ip_portIn = skeletonportMe;
    skeleton_ipaddress = ipaddress;
    skeleton_callback = callback;
    wasSkeletonSet = 1;
  }

#endif

  long double getTickToMeter() { return tickToMeter; }

private:
  long double tickToMeter = 0.000085292090497737556558; // [m/tick]
  long double b =
      0.23; // wheelbase distance in meters, from kobuki manual
            // https://yujinrobot.github.io/kobuki/doxygen/enAppendixProtocolSpecification.html

  std::promise<void> ready_promise;
  std::shared_future<void> readyFuture;
  int wasLaserSet;
  int wasRobotSet;
  int wasCameraSet;
  int wasSkeletonSet;
  // veci na laser
  LaserMeasurement copyOfLaserData;
  void laserprocess();
  std::string laser_ipaddress;
  int laser_ip_portOut;
  int laser_ip_portIn;
  std::thread laserthreadHandle;
  std::function<int(const std::vector<LaserData> &)> laser_callback = nullptr;

  // veci pre podvozok
  CKobuki robot;
  TKobukiData sens;
  std::string robot_ipaddress;
  int robot_ip_portOut;
  int robot_ip_portIn;
  std::thread robotthreadHandle;
  void robotprocess();
  std::function<int(const TKobukiData &)> robot_callback = nullptr;

  udp_communication laserCom;
  udp_communication robotCom;

  // veci pre kameru -- pozor na kameru, neotvarat ak nahodou chcete kameru
  // pripojit na detekciu kostry...
#ifndef DISABLE_OPENCV
  std::string camera_link;
  std::thread camerathreadhandle;
  std::function<int(cv::Mat)> camera_callback = nullptr;
  void imageViewer();
#endif

#ifndef DISABLE_SKELETON
  //--veci pre kostru
  udp_communication skeletonCom;
  std::thread skeletonthreadHandle;
  std::string skeleton_ipaddress;
  int skeleton_ip_portOut;
  int skeleton_ip_portIn;
  void skeletonprocess();
  std::function<int(const skeleton&)> skeleton_callback = nullptr;
#endif
};

#endif // LIBROBOT_H

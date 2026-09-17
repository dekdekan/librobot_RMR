#include <librobot/librobot.h>

#include <string>
#include <type_traits>

using SetCameraParametersSignature =
    void (libRobot::*)(std::function<int(const cv::Mat &)>, std::string);

#ifndef LIBROBOT_HAS_OPENCV
#error "OpenCV-enabled consumers must receive LIBROBOT_HAS_OPENCV."
#endif

#ifdef DISABLE_OPENCV
#error "OpenCV-enabled consumers must not receive DISABLE_OPENCV."
#endif

static_assert(std::is_same_v<decltype(&libRobot::setCameraParameters),
                             SetCameraParametersSignature>);

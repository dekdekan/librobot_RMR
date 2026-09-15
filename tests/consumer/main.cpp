#include <librobot/librobot.h>

#include <concepts>

template <typename T>
concept CompleteType = requires { sizeof(T); };

static_assert(CompleteType<libRobot>);

#if LIBROBOT_CONSUMER_EXPECT_AMCL
#ifndef LIBROBOT_HAS_AMCL
#error "The installed AMCL feature definition did not propagate."
#endif
static_assert(CompleteType<Particle>);
#else
#ifdef LIBROBOT_HAS_AMCL
#error "The installed package leaked its AMCL feature definition."
#endif
#endif

#if LIBROBOT_CONSUMER_EXPECT_OPENCV
#ifndef LIBROBOT_HAS_OPENCV
#error "The installed OpenCV feature definition did not propagate."
#endif
static_assert(CompleteType<cv::Mat>);
#else
#ifdef LIBROBOT_HAS_OPENCV
#error "The installed package leaked its OpenCV feature definition."
#endif
#endif

int main() {
  libRobot robot;
#if LIBROBOT_CONSUMER_EXPECT_OPENCV
  std::function<int(const cv::Mat &)> callback =
      [](const cv::Mat &frame) { return frame.empty() ? 0 : 1; };
  robot.setCameraParameters(callback, "");
#endif
  return 0;
}

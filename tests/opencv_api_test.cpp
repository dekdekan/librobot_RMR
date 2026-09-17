#include <librobot/librobot.h>

#include <functional>

int main() {
  std::function<int(const cv::Mat &)> callback = [](const cv::Mat &frame) {
    return frame.empty() ? 1 : 0;
  };
  libRobot robot;
  robot.setCameraParameters(callback,
                            "http://127.0.0.1:8000/stream.mjpg");
  return 0;
}

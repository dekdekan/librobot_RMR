#ifndef LIBROBOT_AMCL_TYPES_H
#define LIBROBOT_AMCL_TYPES_H

#include <cstddef>
#include <functional>
#include <vector>

struct Particle {
  float x{0};
  float y{0};
  float theta{0};
  float weight{0};
};

struct GridMap {
  int width{0};
  int height{0};
  double offsetX{0};
  double offsetY{0};
  float resolution{0};
  std::vector<int> distanceField;

  int index(int x, int y) const { return y * width + x; }

  int getDistance(int x, int y) const {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return 255;
    }
    return distanceField.at(static_cast<std::size_t>(index(x, y))) - 1;
  }
};

using AMCLCallback = std::function<int(float, float, float)>;

#endif  // LIBROBOT_AMCL_TYPES_H

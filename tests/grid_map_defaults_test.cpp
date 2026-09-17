#include <librobot/amcl_types.h>

#include <iostream>

int main() {
  const GridMap map{};

  if (map.width != 0 || map.height != 0 || map.offsetX != 0.0 ||
      map.offsetY != 0.0 || map.resolution != 0.0F ||
      !map.distanceField.empty()) {
    std::cerr << "GridMap must initialize all public fields to empty defaults.\n";
    return 1;
  }

  return 0;
}

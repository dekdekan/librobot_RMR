#include <librobot/librobot.h>

#include <filesystem>
#include <string>
#include <type_traits>

using SetAMCLParametersSignature =
    bool (libRobot::*)(const std::filesystem::path &, int, double, double,
                       AMCLCallback, std::string *);
using GetBestParticleSignature = Particle (libRobot::*)() const;
using GetAmclMapSignature = const GridMap &(libRobot::*)() const;
using GetGridCoordinatesSignature =
    void (libRobot::*)(double, double, int &, int &) const;

static_assert(std::is_same_v<AMCLCallback,
                             std::function<int(float, float, float)>>);
static_assert(std::is_same_v<decltype(&libRobot::setAMCLParameters),
                             SetAMCLParametersSignature>);
static_assert(std::is_same_v<decltype(&libRobot::getBestParticle),
                             GetBestParticleSignature>);
static_assert(std::is_same_v<decltype(&libRobot::getAmclMap),
                             GetAmclMapSignature>);
static_assert(std::is_same_v<decltype(&libRobot::getGridCoordinates),
                             GetGridCoordinatesSignature>);
static_assert(std::is_default_constructible_v<Particle>);
static_assert(std::is_default_constructible_v<GridMap>);

constexpr Particle defaultParticle{};
static_assert(defaultParticle.x == 0.0F && defaultParticle.y == 0.0F &&
              defaultParticle.theta == 0.0F && defaultParticle.weight == 0.0F);

int main() {
  libRobot robot;
  std::string error;
  AMCLCallback callback = [](float, float, float) { return 0; };
  const bool configured = robot.setAMCLParameters(
      "mapa.txt", 1500, 0.01, 2.0, callback, &error);
  const Particle particle = robot.getBestParticle();
  const GridMap &map = robot.getAmclMap();
  const GridMap defaultMap{};
  int gx = 0;
  int gy = 0;
  robot.getGridCoordinates(particle.x, particle.y, gx, gy);
  return configured || !error.empty() || map.width == gx + gy ||
         defaultMap.width != 0 || defaultMap.height != 0 ||
         defaultMap.offsetX != 0.0 || defaultMap.offsetY != 0.0 ||
         defaultMap.resolution != 0.0F || !defaultMap.distanceField.empty();
}

#include <librobot/librobot.h>

#include <string>

int main() {
  libRobot robot;
  std::string error;
  AMCLCallback callback = [](float, float, float) { return 0; };
  const bool configured = robot.setAMCLParameters(
      "mapa.txt", 1500, 0.01, 2.0, callback, &error);
  const Particle particle = robot.getBestParticle();
  const GridMap &map = robot.getAmclMap();
  int gx = 0;
  int gy = 0;
  robot.getGridCoordinates(particle.x, particle.y, gx, gy);
  return configured || !error.empty() || map.width == gx + gy;
}

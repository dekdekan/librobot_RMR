#pragma once

#include <librobot/amcl_types.h>
#include <librobot/rplidar.h>

#include <amcl/localization.h>

#include <cstdint>
#include <filesystem>
#include <mutex>
#include <string>
#include <vector>

namespace librobot_detail {

class AMCLAdapter {
public:
  explicit AMCLAdapter(std::uint32_t seed = 5489u);

  bool configure(const std::filesystem::path &mapPath, int particleCount,
                 double rotationStd, double translationStd,
                 AMCLCallback callback, std::string *errorMessage);
  void markStarted();

  void updateOdometry(std::uint16_t encoderLeft, std::uint16_t encoderRight,
                      long double tickToMeter, long double wheelBase);
  void processScan(const std::vector<LaserData> &scan);

  Particle bestParticle() const;
  const GridMap &map() const;
  void worldToGrid(double realX, double realY, int &gridX, int &gridY) const;

private:
  static GridMap makeMapSnapshot(const amcl::GridMap &map);
  static Particle makeParticleSnapshot(const amcl::Particle &particle);

  mutable std::mutex mutex_;
  amcl::Localization localization_;
  amcl::GridMap privateMap_;
  std::vector<amcl::Particle> particles_;
  GridMap mapSnapshot_;
  Particle bestParticleSnapshot_;
  float accumulatedDistance_{0.0F};
  float accumulatedRotation_{0.0F};
  std::uint16_t previousEncoderLeft_{0};
  std::uint16_t previousEncoderRight_{0};
  bool odometryInitialized_{false};
  AMCLCallback callback_;
  bool configured_{false};
  bool started_{false};
};

} // namespace librobot_detail

#include "amcl_adapter.h"

#include <cmath>
#include <cstddef>
#include <limits>
#include <utility>

namespace librobot_detail {
namespace {

void setError(std::string *errorMessage, const std::string &message) {
  if (errorMessage != nullptr) {
    *errorMessage = message;
  }
}

} // namespace

AMCLAdapter::AMCLAdapter(std::uint32_t seed) : localization_(seed) {}

bool AMCLAdapter::configure(const std::filesystem::path &mapPath,
                            int particleCount, double rotationStd,
                            double translationStd, AMCLCallback callback,
                            std::string *errorMessage) {
  std::lock_guard lock{mutex_};
  if (errorMessage != nullptr) {
    errorMessage->clear();
  }
  if (started_) {
    setError(errorMessage, "AMCL cannot be configured after robotStart().");
    return false;
  }
  if (configured_) {
    setError(errorMessage, "AMCL has already been configured.");
    return false;
  }
  if (particleCount <= 0) {
    setError(errorMessage, "AMCL particle count must be positive.");
    return false;
  }

  amcl::GridMap loadedMap;
  if (!localization_.loadGridMap(mapPath, loadedMap, errorMessage)) {
    return false;
  }

  localization_.setStandardDeviations(translationStd, rotationStd);
  std::vector<amcl::Particle> initializedParticles =
      localization_.initializeParticles(static_cast<std::size_t>(particleCount),
                                        loadedMap);
  const auto initialBest = localization_.bestParticle(initializedParticles);

  privateMap_ = std::move(loadedMap);
  particles_ = std::move(initializedParticles);
  mapSnapshot_ = makeMapSnapshot(privateMap_);
  bestParticleSnapshot_ =
      initialBest.has_value() ? makeParticleSnapshot(*initialBest) : Particle{};
  accumulatedDistance_ = 0.0F;
  accumulatedRotation_ = 0.0F;
  previousEncoderLeft_ = 0;
  previousEncoderRight_ = 0;
  odometryInitialized_ = false;
  callback_ = std::move(callback);
  configured_ = true;
  return true;
}

void AMCLAdapter::markStarted() {
  std::lock_guard lock{mutex_};
  started_ = true;
}

void AMCLAdapter::updateOdometry(std::uint16_t encoderLeft,
                                 std::uint16_t encoderRight,
                                 long double tickToMeter,
                                 long double wheelBase) {
  std::lock_guard lock{mutex_};
  if (!configured_ || !started_) {
    return;
  }
  if (!odometryInitialized_) {
    previousEncoderLeft_ = encoderLeft;
    previousEncoderRight_ = encoderRight;
    odometryInitialized_ = true;
    return;
  }

  const auto leftDelta = static_cast<std::int16_t>(
      static_cast<std::uint16_t>(encoderLeft - previousEncoderLeft_));
  const auto rightDelta = static_cast<std::int16_t>(
      static_cast<std::uint16_t>(encoderRight - previousEncoderRight_));
  previousEncoderLeft_ = encoderLeft;
  previousEncoderRight_ = encoderRight;

  if (!std::isfinite(tickToMeter) || !std::isfinite(wheelBase) ||
      wheelBase == 0.0L) {
    return;
  }

  const long double distanceMeters =
      (static_cast<long double>(leftDelta) +
       static_cast<long double>(rightDelta)) /
      2.0L * tickToMeter;
  const long double rotationRadians =
      (static_cast<long double>(rightDelta) -
       static_cast<long double>(leftDelta)) /
      wheelBase * tickToMeter;
  if (std::isfinite(distanceMeters) && std::isfinite(rotationRadians) &&
      distanceMeters <= std::numeric_limits<float>::max() / 1000.0L &&
      distanceMeters >= -std::numeric_limits<float>::max() / 1000.0L &&
      rotationRadians <= std::numeric_limits<float>::max() &&
      rotationRadians >= -std::numeric_limits<float>::max()) {
    accumulatedDistance_ += static_cast<float>(distanceMeters * 1000.0L);
    accumulatedRotation_ += static_cast<float>(rotationRadians);
  }
}

void AMCLAdapter::processScan(const std::vector<LaserData> &scan) {
  amcl::Measurement measurement;
  measurement.samples.reserve(scan.size());
  for (const LaserData &sample : scan) {
    measurement.samples.push_back(
        {sample.scanQuality, sample.scanAngle, sample.scanDistance,
         sample.timestamp});
  }

  AMCLCallback callback;
  Particle callbackParticle;
  {
    std::lock_guard lock{mutex_};
    if (!configured_ || !started_) {
      return;
    }

    localization_.step(particles_, measurement, privateMap_,
                       accumulatedDistance_, accumulatedRotation_);
    accumulatedDistance_ = 0.0F;
    accumulatedRotation_ = 0.0F;
    const auto best = localization_.bestParticle(particles_);
    if (best.has_value()) {
      bestParticleSnapshot_ = makeParticleSnapshot(*best);
    }
    callback = callback_;
    callbackParticle = bestParticleSnapshot_;
  }

  if (callback) {
    callback(callbackParticle.x, callbackParticle.y, callbackParticle.theta);
  }
}

Particle AMCLAdapter::bestParticle() const {
  std::lock_guard lock{mutex_};
  return bestParticleSnapshot_;
}

const GridMap &AMCLAdapter::map() const { return mapSnapshot_; }

void AMCLAdapter::worldToGrid(double realX, double realY, int &gridX,
                              int &gridY) const {
  std::lock_guard lock{mutex_};
  if (!configured_ || !std::isfinite(realX) || !std::isfinite(realY) ||
      realX > std::numeric_limits<float>::max() ||
      realX < -std::numeric_limits<float>::max() ||
      realY > std::numeric_limits<float>::max() ||
      realY < -std::numeric_limits<float>::max()) {
    gridX = -1;
    gridY = -1;
    return;
  }
  localization_.worldToGrid(static_cast<float>(realX),
                            static_cast<float>(realY), gridX, gridY,
                            privateMap_);
}

GridMap AMCLAdapter::makeMapSnapshot(const amcl::GridMap &map) {
  return {map.width, map.height, map.offsetX, map.offsetY, map.resolution,
          map.distanceField};
}

Particle AMCLAdapter::makeParticleSnapshot(const amcl::Particle &particle) {
  return {particle.x, particle.y, particle.theta, particle.weight};
}

} // namespace librobot_detail

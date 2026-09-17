#include <librobot/librobot.h>

template <typename Robot>
concept HasAMCLApi = requires(const Robot &robot) {
  robot.getBestParticle();
  robot.getAmclMap();
};

#ifndef DISABLE_AMCL
#error "AMCL-disabled consumers must receive the legacy DISABLE_AMCL guard."
#endif

#ifdef LIBROBOT_HAS_AMCL
#error "AMCL-disabled consumers must not receive LIBROBOT_HAS_AMCL."
#endif

static_assert(!HasAMCLApi<libRobot>);

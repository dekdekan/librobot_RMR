#include <librobot/librobot.h>

#ifndef DISABLE_SKELETON
#error "Skeleton-disabled builds must publish DISABLE_SKELETON."
#endif

#ifdef LIBROBOT_HAS_SKELETON
#error "Skeleton-disabled builds must not publish LIBROBOT_HAS_SKELETON."
#endif

static_assert(sizeof(skeleton) == 75 * 3 * sizeof(double));

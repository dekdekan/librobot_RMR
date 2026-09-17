#include <librobot/librobot.h>

#ifndef DISABLE_OPENCV
#error "OpenCV-disabled consumers must receive the legacy DISABLE_OPENCV guard."
#endif

#ifdef LIBROBOT_HAS_OPENCV
#error "OpenCV-disabled consumers must not receive LIBROBOT_HAS_OPENCV."
#endif

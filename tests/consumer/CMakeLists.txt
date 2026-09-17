cmake_minimum_required(VERSION 3.21)

project(librobot_consumer LANGUAGES CXX)

set(LIBROBOT_CONSUMER_EXPECT_AMCL ON CACHE BOOL
    "Require AMCL in the installed librobot package")
set(LIBROBOT_CONSUMER_EXPECT_OPENCV ON CACHE BOOL
    "Require OpenCV in the installed librobot package")
set(LIBROBOT_CONSUMER_EXPECT_SKELETON ON CACHE BOOL
    "Require skeleton support in the installed librobot package")

find_package(librobot 1.1 CONFIG REQUIRED)

if(LIBROBOT_CONSUMER_EXPECT_AMCL)
    if(NOT librobot_AMCL_ENABLED)
        message(FATAL_ERROR "Installed librobot does not contain AMCL")
    endif()
elseif(librobot_AMCL_ENABLED)
    message(FATAL_ERROR "Installed librobot unexpectedly contains AMCL")
endif()

if(LIBROBOT_CONSUMER_EXPECT_OPENCV)
    if(NOT librobot_OPENCV_ENABLED)
        message(FATAL_ERROR "Installed librobot does not contain OpenCV support")
    endif()
elseif(librobot_OPENCV_ENABLED)
    message(FATAL_ERROR "Installed librobot unexpectedly contains OpenCV support")
endif()

if(LIBROBOT_CONSUMER_EXPECT_SKELETON)
    if(NOT librobot_SKELETON_ENABLED)
        message(FATAL_ERROR "Installed librobot does not contain skeleton support")
    endif()
elseif(librobot_SKELETON_ENABLED)
    message(FATAL_ERROR "Installed librobot unexpectedly contains skeleton support")
endif()

add_executable(librobot_consumer main.cpp)
target_compile_definitions(librobot_consumer PRIVATE
    LIBROBOT_CONSUMER_EXPECT_AMCL=$<BOOL:${LIBROBOT_CONSUMER_EXPECT_AMCL}>
    LIBROBOT_CONSUMER_EXPECT_OPENCV=$<BOOL:${LIBROBOT_CONSUMER_EXPECT_OPENCV}>
    LIBROBOT_CONSUMER_EXPECT_SKELETON=$<BOOL:${LIBROBOT_CONSUMER_EXPECT_SKELETON}>
)
target_link_libraries(librobot_consumer PRIVATE librobot::librobot)

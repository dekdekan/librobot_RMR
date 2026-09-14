cmake_minimum_required(VERSION 3.21)

project(librobot VERSION 1.1.0 LANGUAGES CXX)

option(LIBROBOT_ENABLE_AMCL "Build AMCL localization support" OFF)
option(LIBROBOT_ENABLE_OPENCV "Build camera support using OpenCV" ON)
option(LIBROBOT_DISABLE_OPENCV "Deprecated: disable OpenCV support" OFF)
option(LIBROBOT_BUILD_TESTING "Build librobot tests when used as a subproject" OFF)
option(LIBROBOT_DISABLE_SKELETON "Disable skeleton module" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(LIBROBOT_DISABLE_OPENCV)
    set(LIBROBOT_ENABLE_OPENCV OFF CACHE BOOL "Build camera support using OpenCV" FORCE)
endif()

if(LIBROBOT_ENABLE_OPENCV)
    find_package(OpenCV REQUIRED)
endif()

include(GNUInstallDirs)
add_subdirectory(src)

include(CTest)
if(BUILD_TESTING AND (PROJECT_IS_TOP_LEVEL OR LIBROBOT_BUILD_TESTING))
    add_subdirectory(tests)
endif()

include(CMakePackageConfigHelpers)
configure_package_config_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/librobotConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/librobotConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/librobot
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/librobotConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(EXPORT librobotTargets
    FILE librobotTargets.cmake
    NAMESPACE librobot::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/librobot
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/librobotConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/librobotConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/librobot
)

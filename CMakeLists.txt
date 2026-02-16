cmake_minimum_required(VERSION 3.16)

project(librobot VERSION 1.0.0 LANGUAGES CXX)

option(LIBROBOT_DISABLE_OPENCV "Disable OpenCV support" ON)
option(LIBROBOT_DISABLE_SKELETON "Disable skeleton module" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT LIBROBOT_DISABLE_OPENCV)
    find_package(OpenCV REQUIRED)
endif()

include(GNUInstallDirs)
add_subdirectory(src)

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

cmake_minimum_required(VERSION 3.16)
project(librobot VERSION 1.1.0 LANGUAGES CXX)

option(LIBROBOT_DISABLE_OPENCV "Disable OpenCV support" ON)
option(LIBROBOT_DISABLE_SKELETON "Disable skeleton module" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT LIBROBOT_DISABLE_OPENCV)
    find_package(OpenCV REQUIRED)
endif()

include(GNUInstallDirs)

# Ensure headers are installed! 
# (Assuming your headers are in an 'include' folder)
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

add_subdirectory(src)

# --- CMake Package Logic ---
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

set(CPACK_PACKAGE_NAME "RobotLib")
set(CPACK_PACKAGE_VENDOR "Tomas Jurov")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A cross-platform robot library with Qt and OpenCV")

if(WIN32)
    set(CPACK_NSIS_MODIFY_PATH ON)
    set(CPACK_NSIS_HELP_LINK "https://github.com/your-repo")
endif()

set(CPACK_GENERATOR "ZIP") 
if(WIN32)
    list(APPEND CPACK_GENERATOR "NSIS") 
elseif(APPLE)
    list(APPEND CPACK_GENERATOR "productbuild") 
    list(APPEND CPACK_GENERATOR "DragNDrop") 
else()
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Tomas Jurov")
    list(APPEND CPACK_GENERATOR "DEB") 
endif()

include(CPack)
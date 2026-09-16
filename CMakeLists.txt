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
    find_package(OpenCV 4 REQUIRED COMPONENTS
        core
        highgui
        imgcodecs
        imgproc
        videoio
    )
endif()

include(CTest)

if(LIBROBOT_ENABLE_AMCL)
    include(FetchContent)

    # AMCL release v1.0.0 resolves to this immutable revision.
    set(LIBROBOT_AMCL_GIT_REVISION
        "dc39c300ec2bb60cae13603a5cae460e325f6c26"
        CACHE STRING "Immutable AMCL source revision")
    FetchContent_Declare(amcl
        GIT_REPOSITORY git@github.com:dekdekan/amcl.git
        GIT_TAG "${LIBROBOT_AMCL_GIT_REVISION}"
        GIT_SHALLOW FALSE
    )

    set(_librobot_saved_build_shared_libs "${BUILD_SHARED_LIBS}")
    set(_librobot_saved_build_testing "${BUILD_TESTING}")
    set(BUILD_SHARED_LIBS OFF)
    set(BUILD_TESTING OFF)

    FetchContent_GetProperties(amcl)
    if(NOT amcl_POPULATED)
        if(POLICY CMP0169)
            cmake_policy(PUSH)
            cmake_policy(SET CMP0169 OLD)
        endif()
        FetchContent_Populate(amcl)
        if(POLICY CMP0169)
            cmake_policy(POP)
        endif()
        add_subdirectory("${amcl_SOURCE_DIR}" "${amcl_BINARY_DIR}" EXCLUDE_FROM_ALL)
    endif()

    set(BUILD_SHARED_LIBS "${_librobot_saved_build_shared_libs}")
    set(BUILD_TESTING "${_librobot_saved_build_testing}")
    # AMCL is embedded implementation, not part of librobot's dynamic ABI.
    # Compile every object from the static archive hidden so AppleClang does
    # not re-export it when the archive is linked into the dylib.  GNU ld's
    # archive localization below provides an additional ELF boundary.
    set_target_properties(amcl PROPERTIES
        POSITION_INDEPENDENT_CODE ON
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN YES
    )
endif()

include(GNUInstallDirs)
add_subdirectory(src)

if(BUILD_TESTING AND (PROJECT_IS_TOP_LEVEL OR LIBROBOT_BUILD_TESTING))
    add_subdirectory(tests)
endif()

include(CMakePackageConfigHelpers)
if(LIBROBOT_ENABLE_AMCL)
    set(LIBROBOT_AMCL_ENABLED_LITERAL TRUE)
else()
    set(LIBROBOT_AMCL_ENABLED_LITERAL FALSE)
endif()
if(LIBROBOT_ENABLE_OPENCV)
    set(LIBROBOT_OPENCV_ENABLED_LITERAL TRUE)
else()
    set(LIBROBOT_OPENCV_ENABLED_LITERAL FALSE)
endif()
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

if(PROJECT_IS_TOP_LEVEL)
    include(cmake/Packaging.cmake)
endif()

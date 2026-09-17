cmake_minimum_required(VERSION 3.21)

project(librobot_parent_subproject LANGUAGES CXX)

if(NOT DEFINED LIBROBOT_SOURCE_DIR)
    message(FATAL_ERROR "LIBROBOT_SOURCE_DIR must identify the librobot source tree.")
endif()

set(BUILD_TESTING ON CACHE BOOL "Build tests in the parent fixture." FORCE)
set(LIBROBOT_ENABLE_AMCL "${LIBROBOT_PARENT_ENABLE_AMCL}" CACHE BOOL
    "Match the parent fixture's AMCL state to the outer librobot build." FORCE)
set(LIBROBOT_ENABLE_OPENCV OFF CACHE BOOL "Avoid OpenCV in the parent fixture." FORCE)

add_subdirectory("${LIBROBOT_SOURCE_DIR}" librobot)

set(parent_errors)
if(TARGET librobot_public_api_test)
    list(APPEND parent_errors "librobot test targets are built by default as a subproject")
endif()

get_target_property(librobot_compile_features librobot INTERFACE_COMPILE_FEATURES)
list(FIND librobot_compile_features cxx_std_20 cxx_std_20_index)
if(cxx_std_20_index EQUAL -1)
    list(APPEND parent_errors "librobot does not export the C++20 compile feature")
endif()

if(parent_errors)
    list(JOIN parent_errors "; " parent_error_message)
    message(FATAL_ERROR "${parent_error_message}")
endif()

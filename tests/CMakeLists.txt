if(LIBROBOT_ENABLE_AMCL)
    add_library(librobot_public_api_test OBJECT public_api_test.cpp)
    target_link_libraries(librobot_public_api_test PRIVATE librobot::librobot)
else()
    add_library(librobot_amcl_feature_off_probe OBJECT amcl_feature_off_probe.cpp)
    target_link_libraries(librobot_amcl_feature_off_probe PRIVATE librobot::librobot)
endif()

if(LIBROBOT_ENABLE_OPENCV)
    add_library(librobot_opencv_feature_probe OBJECT opencv_feature_probe.cpp)
    target_link_libraries(librobot_opencv_feature_probe PRIVATE librobot::librobot)
else()
    add_library(librobot_opencv_feature_off_probe OBJECT opencv_feature_off_probe.cpp)
    target_link_libraries(librobot_opencv_feature_off_probe PRIVATE librobot::librobot)
endif()

set(librobot_parent_make_program "${CMAKE_MAKE_PROGRAM}")
set(librobot_parent_archiver "${CMAKE_AR}")
if(CMAKE_GENERATOR STREQUAL "NMake Makefiles")
    get_filename_component(librobot_msvc_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    set(librobot_parent_make_program "${librobot_msvc_bin_dir}/nmake.exe")
    set(librobot_parent_archiver "${librobot_msvc_bin_dir}/lib.exe")
endif()

add_test(
    NAME librobot.generated_config_opencv_dependency
    COMMAND ${CMAKE_COMMAND}
        -DCONFIG_FILE=${CMAKE_BINARY_DIR}/librobotConfig.cmake
        -DEXPECT_OPENCV=${LIBROBOT_ENABLE_OPENCV}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/verify_generated_config.cmake
)

add_test(
    NAME librobot.parent_subproject_configure
    COMMAND ${CMAKE_COMMAND}
        -S ${CMAKE_CURRENT_SOURCE_DIR}/parent-subproject
        -B ${CMAKE_CURRENT_BINARY_DIR}/parent-subproject
        -G "${CMAKE_GENERATOR}"
        -DCMAKE_MAKE_PROGRAM:FILEPATH=${librobot_parent_make_program}
        -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
        -DCMAKE_AR:FILEPATH=${librobot_parent_archiver}
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DLIBROBOT_SOURCE_DIR=${CMAKE_SOURCE_DIR}
)

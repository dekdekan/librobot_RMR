if(LIBROBOT_ENABLE_AMCL)
    add_library(librobot_public_api_test OBJECT public_api_test.cpp)
    target_link_libraries(librobot_public_api_test PRIVATE librobot::librobot)

    add_executable(librobot_amcl_integration_test
        amcl_integration_test.cpp
        ${PROJECT_SOURCE_DIR}/src/amcl_adapter.cpp
    )
    target_include_directories(librobot_amcl_integration_test PRIVATE
        ${PROJECT_SOURCE_DIR}/src
    )
    target_compile_definitions(librobot_amcl_integration_test PRIVATE
        LIBROBOT_TEST_FIXTURE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/fixtures"
    )
    target_link_libraries(librobot_amcl_integration_test PRIVATE
        librobot::librobot
        amcl::amcl
    )
    add_test(NAME librobot.amcl_integration COMMAND librobot_amcl_integration_test)
    set_tests_properties(librobot.amcl_integration PROPERTIES TIMEOUT 60)
else()
    add_library(librobot_amcl_feature_off_probe OBJECT amcl_feature_off_probe.cpp)
    target_link_libraries(librobot_amcl_feature_off_probe PRIVATE librobot::librobot)
endif()

if(LIBROBOT_ENABLE_OPENCV)
    add_library(librobot_opencv_feature_probe OBJECT opencv_feature_probe.cpp)
    target_link_libraries(librobot_opencv_feature_probe PRIVATE librobot::librobot)

    add_executable(librobot_opencv_api_test opencv_api_test.cpp)
    target_link_libraries(librobot_opencv_api_test PRIVATE librobot::librobot)
    add_test(NAME librobot.opencv_api COMMAND librobot_opencv_api_test)
else()
    add_library(librobot_opencv_feature_off_probe OBJECT opencv_feature_off_probe.cpp)
    target_link_libraries(librobot_opencv_feature_off_probe PRIVATE librobot::librobot)
endif()

add_executable(librobot_runtime_lifecycle_test runtime_lifecycle_test.cpp)
target_link_libraries(librobot_runtime_lifecycle_test PRIVATE librobot::librobot)
add_test(NAME librobot.runtime_lifecycle COMMAND librobot_runtime_lifecycle_test)

add_executable(librobot_udp_command_ownership_test
    udp_command_ownership_test.cpp
    ${PROJECT_SOURCE_DIR}/src/udp_communication.cpp
)
target_link_libraries(librobot_udp_command_ownership_test PRIVATE librobot::librobot)
add_test(NAME librobot.udp_command_ownership
    COMMAND librobot_udp_command_ownership_test)
set_tests_properties(librobot.udp_command_ownership PROPERTIES TIMEOUT 60)

add_executable(librobot_runtime_worker_test
    runtime_worker_test.cpp
    ${PROJECT_SOURCE_DIR}/src/CKobuki.cpp
)
target_link_libraries(librobot_runtime_worker_test PRIVATE librobot::librobot)
add_test(NAME librobot.runtime_worker COMMAND librobot_runtime_worker_test)
set_tests_properties(librobot.runtime_worker PROPERTIES TIMEOUT 60)

add_executable(librobot_grid_map_defaults_test grid_map_defaults_test.cpp)
target_link_libraries(librobot_grid_map_defaults_test PRIVATE librobot::librobot)
add_test(NAME librobot.grid_map_defaults COMMAND librobot_grid_map_defaults_test)

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

set(librobot_parent_subproject_arguments
        -S ${CMAKE_CURRENT_SOURCE_DIR}/parent-subproject
        -B ${CMAKE_CURRENT_BINARY_DIR}/parent-subproject
        -G "${CMAKE_GENERATOR}"
        -DCMAKE_MAKE_PROGRAM:FILEPATH=${librobot_parent_make_program}
        -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
        -DCMAKE_AR:FILEPATH=${librobot_parent_archiver}
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DLIBROBOT_SOURCE_DIR=${PROJECT_SOURCE_DIR}
        -DLIBROBOT_PARENT_ENABLE_AMCL=${LIBROBOT_ENABLE_AMCL}
)
if(LIBROBOT_ENABLE_AMCL AND FETCHCONTENT_SOURCE_DIR_AMCL)
    list(APPEND librobot_parent_subproject_arguments
        -DFETCHCONTENT_SOURCE_DIR_AMCL=${FETCHCONTENT_SOURCE_DIR_AMCL}
    )
endif()

add_test(
    NAME librobot.parent_subproject_configure
    COMMAND ${CMAKE_COMMAND} ${librobot_parent_subproject_arguments}
)

if(WIN32)
    string(REPLACE ";" "\\;" librobot_test_path "$ENV{PATH}")
    set(librobot_test_runtime_path
        "$<TARGET_FILE_DIR:librobot>\\;${LIBROBOT_QT_RUNTIME_DIR}")
    if(LIBROBOT_ENABLE_OPENCV)
        get_filename_component(librobot_test_opencv_runtime_dir
            "${OpenCV_DIR}/../bin" ABSOLUTE)
        string(APPEND librobot_test_runtime_path
            "\\;${librobot_test_opencv_runtime_dir}")
    endif()
    string(APPEND librobot_test_runtime_path "\\;${librobot_test_path}")

    set(librobot_runtime_tests
        librobot.runtime_lifecycle
        librobot.udp_command_ownership
        librobot.runtime_worker
    )
    if(LIBROBOT_ENABLE_AMCL)
        list(APPEND librobot_runtime_tests librobot.amcl_integration)
    endif()
    if(LIBROBOT_ENABLE_OPENCV)
        list(APPEND librobot_runtime_tests librobot.opencv_api)
    endif()
    set_tests_properties(${librobot_runtime_tests} PROPERTIES
        ENVIRONMENT "PATH=${librobot_test_runtime_path}"
    )
endif()

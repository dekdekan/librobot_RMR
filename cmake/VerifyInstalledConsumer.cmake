foreach(required_variable IN ITEMS
        LIBROBOT_BUILD_DIR
        LIBROBOT_INSTALL_PREFIX
        LIBROBOT_CONSUMER_SOURCE_DIR
        LIBROBOT_CONSUMER_BINARY_DIR
        LIBROBOT_BUILD_TYPE
        LIBROBOT_GENERATOR
        LIBROBOT_CXX_COMPILER
        LIBROBOT_MAKE_PROGRAM
        LIBROBOT_EXPECT_AMCL
        LIBROBOT_EXPECT_OPENCV
        LIBROBOT_INSTALL_LIBDIR)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "Missing required variable ${required_variable}")
    endif()
endforeach()

file(REMOVE_RECURSE
    "${LIBROBOT_INSTALL_PREFIX}"
    "${LIBROBOT_CONSUMER_BINARY_DIR}"
)

execute_process(
    COMMAND "${CMAKE_COMMAND}" --install "${LIBROBOT_BUILD_DIR}"
        --prefix "${LIBROBOT_INSTALL_PREFIX}"
        --config "${LIBROBOT_BUILD_TYPE}"
    RESULT_VARIABLE install_result
    OUTPUT_VARIABLE install_output
    ERROR_VARIABLE install_error
)
if(NOT install_result EQUAL 0)
    message(FATAL_ERROR
        "librobot install failed (${install_result}).\n${install_output}${install_error}")
endif()

set(package_dir
    "${LIBROBOT_INSTALL_PREFIX}/${LIBROBOT_INSTALL_LIBDIR}/cmake/librobot")
set(config_file "${package_dir}/librobotConfig.cmake")
set(targets_file "${package_dir}/librobotTargets.cmake")
if(NOT EXISTS "${config_file}" OR NOT EXISTS "${targets_file}")
    message(FATAL_ERROR "Installed librobot package metadata is incomplete")
endif()

file(READ "${config_file}" config_contents)
if(LIBROBOT_EXPECT_AMCL)
    set(expected_amcl TRUE)
else()
    set(expected_amcl FALSE)
endif()
if(LIBROBOT_EXPECT_OPENCV)
    set(expected_opencv TRUE)
else()
    set(expected_opencv FALSE)
endif()
if(NOT config_contents MATCHES
        "set\\(librobot_AMCL_ENABLED ${expected_amcl}\\)")
    message(FATAL_ERROR "Installed AMCL feature metadata is not literal ${expected_amcl}")
endif()
if(NOT config_contents MATCHES
        "set\\(librobot_OPENCV_ENABLED ${expected_opencv}\\)")
    message(FATAL_ERROR "Installed OpenCV feature metadata is not literal ${expected_opencv}")
endif()

file(GLOB target_fragments "${package_dir}/librobotTargets-*.cmake")
set(package_contents "${config_contents}")
file(READ "${targets_file}" targets_contents)
string(APPEND package_contents "\n${targets_contents}")
foreach(fragment IN LISTS target_fragments)
    file(READ "${fragment}" fragment_contents)
    string(APPEND package_contents "\n${fragment_contents}")
endforeach()

foreach(forbidden_value IN ITEMS
        "${LIBROBOT_FORBIDDEN_SOURCE_DIR}"
        "${LIBROBOT_BUILD_DIR}"
        "${LIBROBOT_AMCL_SOURCE_DIR}")
    if(forbidden_value)
        file(TO_CMAKE_PATH "${forbidden_value}" normalized_forbidden)
        string(FIND "${package_contents}" "${normalized_forbidden}" forbidden_index)
        if(NOT forbidden_index EQUAL -1)
            message(FATAL_ERROR
                "Installed package metadata contains private/build path: ${normalized_forbidden}")
        endif()
    endif()
endforeach()
if(package_contents MATCHES "amcl::amcl|amcl-build|git@github.com:dekdekan/amcl")
    message(FATAL_ERROR "Installed package metadata leaks private AMCL details")
endif()

string(TOUPPER "${LIBROBOT_BUILD_TYPE}" build_type_upper)
if(WIN32)
    if(build_type_upper STREQUAL "DEBUG")
        set(expected_library_name "librobot_d")
    else()
        set(expected_library_name "librobot")
    endif()
    if(NOT EXISTS "${LIBROBOT_INSTALL_PREFIX}/bin/${expected_library_name}.dll")
        message(FATAL_ERROR "Installed runtime DLL is missing")
    endif()
    if(NOT EXISTS
            "${LIBROBOT_INSTALL_PREFIX}/${LIBROBOT_INSTALL_LIBDIR}/${expected_library_name}.lib")
        message(FATAL_ERROR "Installed import library is missing")
    endif()
    if(NOT package_contents MATCHES
            "IMPORTED_LOCATION_${build_type_upper}[^\n]*bin/.*${expected_library_name}\\.dll")
        message(FATAL_ERROR "Imported runtime location is missing for ${build_type_upper}")
    endif()
    if(NOT package_contents MATCHES
            "IMPORTED_IMPLIB_${build_type_upper}[^\n]*${LIBROBOT_INSTALL_LIBDIR}/.*${expected_library_name}\\.lib")
        message(FATAL_ERROR "Imported library location is missing for ${build_type_upper}")
    endif()
endif()

set(configure_command
    "${CMAKE_COMMAND}"
    -S "${LIBROBOT_CONSUMER_SOURCE_DIR}"
    -B "${LIBROBOT_CONSUMER_BINARY_DIR}"
    -G "${LIBROBOT_GENERATOR}"
    "-DCMAKE_BUILD_TYPE=${LIBROBOT_BUILD_TYPE}"
    "-DCMAKE_CXX_COMPILER:FILEPATH=${LIBROBOT_CXX_COMPILER}"
    "-DCMAKE_MAKE_PROGRAM:FILEPATH=${LIBROBOT_MAKE_PROGRAM}"
    "-Dlibrobot_DIR:PATH=${package_dir}"
    "-DLIBROBOT_CONSUMER_EXPECT_AMCL=${LIBROBOT_EXPECT_AMCL}"
    "-DLIBROBOT_CONSUMER_EXPECT_OPENCV=${LIBROBOT_EXPECT_OPENCV}"
)
if(LIBROBOT_QT6_DIR)
    list(APPEND configure_command "-DQt6_DIR:PATH=${LIBROBOT_QT6_DIR}")
endif()
if(LIBROBOT_OPENCV_DIR)
    list(APPEND configure_command "-DOpenCV_DIR:PATH=${LIBROBOT_OPENCV_DIR}")
endif()
if(LIBROBOT_RC_COMPILER)
    list(APPEND configure_command
        "-DCMAKE_RC_COMPILER:FILEPATH=${LIBROBOT_RC_COMPILER}")
endif()
if(LIBROBOT_MT)
    list(APPEND configure_command "-DCMAKE_MT:FILEPATH=${LIBROBOT_MT}")
endif()

execute_process(
    COMMAND ${configure_command}
    RESULT_VARIABLE configure_result
    OUTPUT_VARIABLE configure_output
    ERROR_VARIABLE configure_error
)
if(NOT configure_result EQUAL 0)
    message(FATAL_ERROR
        "External consumer configure failed (${configure_result}).\n"
        "${configure_output}${configure_error}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${LIBROBOT_CONSUMER_BINARY_DIR}"
        --config "${LIBROBOT_BUILD_TYPE}"
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error
)
if(NOT build_result EQUAL 0)
    message(FATAL_ERROR
        "External consumer build failed (${build_result}).\n${build_output}${build_error}")
endif()

set(consumer_executable
    "${LIBROBOT_CONSUMER_BINARY_DIR}/librobot_consumer${LIBROBOT_EXECUTABLE_SUFFIX}")
if(NOT EXISTS "${consumer_executable}")
    message(FATAL_ERROR "External consumer executable is missing")
endif()

if(WIN32)
    set(runtime_path "${LIBROBOT_INSTALL_PREFIX}/bin")
    if(LIBROBOT_QT_RUNTIME_DIR)
        string(APPEND runtime_path ";${LIBROBOT_QT_RUNTIME_DIR}")
    endif()
    if(LIBROBOT_OPENCV_RUNTIME_DIR)
        string(APPEND runtime_path ";${LIBROBOT_OPENCV_RUNTIME_DIR}")
    endif()
    string(APPEND runtime_path ";$ENV{PATH}")
    string(REPLACE ";" "\\;" escaped_runtime_path "${runtime_path}")
    set(run_command "${CMAKE_COMMAND}" -E env
        "PATH=${escaped_runtime_path}" "${consumer_executable}")
else()
    set(run_command "${consumer_executable}")
endif()

execute_process(
    COMMAND ${run_command}
    RESULT_VARIABLE run_result
    OUTPUT_VARIABLE run_output
    ERROR_VARIABLE run_error
)
if(NOT run_result EQUAL 0)
    message(FATAL_ERROR
        "External consumer run failed (${run_result}).\n${run_output}${run_error}")
endif()

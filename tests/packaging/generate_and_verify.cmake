foreach(required_variable IN ITEMS
        LIBROBOT_CPACK_COMMAND
        LIBROBOT_CPACK_CONFIG
        LIBROBOT_PACKAGE_GENERATOR
        LIBROBOT_PACKAGE_FILE
        LIBROBOT_EXTRACT_DIRECTORY)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "${required_variable} is required")
    endif()
endforeach()

file(REMOVE "${LIBROBOT_PACKAGE_FILE}")
file(REMOVE_RECURSE "${LIBROBOT_EXTRACT_DIRECTORY}")

execute_process(
    COMMAND "${LIBROBOT_CPACK_COMMAND}"
        --config "${LIBROBOT_CPACK_CONFIG}"
        -C Release
        -G "${LIBROBOT_PACKAGE_GENERATOR}"
    RESULT_VARIABLE package_result
    OUTPUT_VARIABLE package_output
    ERROR_VARIABLE package_error)
if(NOT package_result EQUAL 0)
    message(FATAL_ERROR
        "${LIBROBOT_PACKAGE_GENERATOR} generation failed:\n"
        "${package_output}${package_error}")
endif()
if(NOT EXISTS "${LIBROBOT_PACKAGE_FILE}")
    message(FATAL_ERROR
        "CPack did not create the exact expected artifact: ${LIBROBOT_PACKAGE_FILE}")
endif()

if(NOT LIBROBOT_VERIFY_LAYOUT)
    return()
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-DLIBROBOT_PACKAGE_FILE=${LIBROBOT_PACKAGE_FILE}"
        "-DLIBROBOT_EXTRACT_DIRECTORY=${LIBROBOT_EXTRACT_DIRECTORY}"
        "-DLIBROBOT_PACKAGE_FORMAT=${LIBROBOT_PACKAGE_FORMAT}"
        "-DLIBROBOT_LAYOUT_PREFIX=${LIBROBOT_LAYOUT_PREFIX}"
        "-DLIBROBOT_REQUIRE_BIN=${LIBROBOT_REQUIRE_BIN}"
        "-DLIBROBOT_REQUIRE_WINDOWS_CONFIGS=${LIBROBOT_REQUIRE_WINDOWS_CONFIGS}"
        "-DLIBROBOT_REQUIRE_MACOS_SCRIPTS=${LIBROBOT_REQUIRE_MACOS_SCRIPTS}"
        "-DLIBROBOT_DPKG_DEB=${LIBROBOT_DPKG_DEB}"
        -P "${LIBROBOT_VERIFY_SCRIPT}"
    RESULT_VARIABLE verify_result
    OUTPUT_VARIABLE verify_output
    ERROR_VARIABLE verify_error)

file(REMOVE_RECURSE "${LIBROBOT_EXTRACT_DIRECTORY}")
if(NOT verify_result EQUAL 0)
    message(FATAL_ERROR
        "${LIBROBOT_PACKAGE_GENERATOR} layout verification failed:\n"
        "${verify_output}${verify_error}")
endif()

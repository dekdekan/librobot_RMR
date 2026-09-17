foreach(required_variable IN ITEMS
        LIBROBOT_TEST_DIRECTORY
        LIBROBOT_FORBIDDEN_PATH
        LIBROBOT_EXPECTED_ERROR
        LIBROBOT_VERIFY_SCRIPT)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "${required_variable} is required")
    endif()
endforeach()

set(stage_directory "${LIBROBOT_TEST_DIRECTORY}/stage")
set(extract_directory "${LIBROBOT_TEST_DIRECTORY}/extract")
set(package_file "${LIBROBOT_TEST_DIRECTORY}/fixture.tar.gz")
file(REMOVE_RECURSE "${LIBROBOT_TEST_DIRECTORY}")
file(MAKE_DIRECTORY
    "${stage_directory}/lib/cmake/librobot"
    "${stage_directory}/include/librobot")
file(WRITE "${stage_directory}/lib/cmake/librobot/librobotConfig.cmake" "# fixture\n")
get_filename_component(forbidden_directory
    "${stage_directory}/${LIBROBOT_FORBIDDEN_PATH}" DIRECTORY)
file(MAKE_DIRECTORY "${forbidden_directory}")
file(WRITE "${stage_directory}/${LIBROBOT_FORBIDDEN_PATH}" "fixture\n")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar cf "${package_file}"
        --format=gnutar .
    WORKING_DIRECTORY "${stage_directory}"
    RESULT_VARIABLE archive_result
    ERROR_VARIABLE archive_error)
if(NOT archive_result EQUAL 0)
    file(REMOVE_RECURSE "${LIBROBOT_TEST_DIRECTORY}")
    message(FATAL_ERROR "Could not create fixture archive: ${archive_error}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-DLIBROBOT_PACKAGE_FILE=${package_file}"
        "-DLIBROBOT_EXTRACT_DIRECTORY=${extract_directory}"
        -P "${LIBROBOT_VERIFY_SCRIPT}"
    RESULT_VARIABLE verify_result
    OUTPUT_VARIABLE verify_output
    ERROR_VARIABLE verify_error)
set(verify_message "${verify_output}${verify_error}")

file(REMOVE_RECURSE "${LIBROBOT_TEST_DIRECTORY}")
if(verify_result EQUAL 0)
    message(FATAL_ERROR
        "Layout verifier accepted forbidden path ${LIBROBOT_FORBIDDEN_PATH}")
endif()
string(FIND "${verify_message}" "${LIBROBOT_EXPECTED_ERROR}" error_index)
if(error_index EQUAL -1)
    message(FATAL_ERROR
        "Layout verifier failed for the wrong reason:\n${verify_message}")
endif()

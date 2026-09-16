foreach(required_variable IN ITEMS
        LIBROBOT_NSIS_CUSTOMIZER
        LIBROBOT_NSIS_STOCK_TEMPLATE
        LIBROBOT_NSIS_OUTPUT_TEMPLATE
        LIBROBOT_NSIS_TEST_DIRECTORY
        LIBROBOT_NSIS_VERIFY_SCRIPT)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "${required_variable} is required")
    endif()
endforeach()

include("${LIBROBOT_NSIS_CUSTOMIZER}")
librobot_customize_nsis_template(
    "${LIBROBOT_NSIS_STOCK_TEMPLATE}"
    "${LIBROBOT_NSIS_OUTPUT_TEMPLATE}")

execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-DLIBROBOT_NSIS_TEMPLATE=${LIBROBOT_NSIS_OUTPUT_TEMPLATE}"
        "-DLIBROBOT_NSIS_TEST_DIRECTORY=${LIBROBOT_NSIS_TEST_DIRECTORY}"
        -P "${LIBROBOT_NSIS_VERIFY_SCRIPT}"
    RESULT_VARIABLE verify_result)
if(NOT verify_result EQUAL 0)
    message(FATAL_ERROR
        "Customized CMake 3.31 NSIS template verification failed (${verify_result})")
endif()

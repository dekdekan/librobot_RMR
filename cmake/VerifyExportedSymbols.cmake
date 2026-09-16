if(DEFINED LIBROBOT_SYMBOL_DUMP_FILE)
    file(READ "${LIBROBOT_SYMBOL_DUMP_FILE}" symbols)
elseif(DEFINED LIBROBOT_SYMBOL_DUMP)
    set(symbols "${LIBROBOT_SYMBOL_DUMP}")
else()
    foreach(required_variable IN ITEMS
            LIBROBOT_LIBRARY
            LIBROBOT_NM
            LIBROBOT_PLATFORM)
        if(NOT DEFINED ${required_variable})
            message(FATAL_ERROR "Missing required variable ${required_variable}")
        endif()
    endforeach()
    if(NOT EXISTS "${LIBROBOT_LIBRARY}")
        message(FATAL_ERROR "librobot shared library does not exist: ${LIBROBOT_LIBRARY}")
    endif()

    if(LIBROBOT_PLATFORM STREQUAL "Darwin")
        set(nm_arguments -gU -C "${LIBROBOT_LIBRARY}")
    elseif(LIBROBOT_PLATFORM STREQUAL "Linux")
        set(nm_arguments -D --defined-only -C "${LIBROBOT_LIBRARY}")
    else()
        message(FATAL_ERROR "Unsupported symbol-inspection platform: ${LIBROBOT_PLATFORM}")
    endif()

    execute_process(
        COMMAND "${LIBROBOT_NM}" ${nm_arguments}
        RESULT_VARIABLE nm_result
        OUTPUT_VARIABLE symbols
        ERROR_VARIABLE nm_error
    )
    if(NOT nm_result EQUAL 0)
        message(FATAL_ERROR
            "Could not inspect librobot exports (${nm_result}).\n${nm_error}")
    endif()
endif()

foreach(public_pattern IN ITEMS
        "libRobot::libRobot\\("
        "libRobot::~libRobot\\("
        "libRobot::robotStart\\("
        "libRobot::setAMCLParameters\\(")
    if(NOT symbols MATCHES "${public_pattern}")
        message(FATAL_ERROR
            "The installed shared library is missing public ABI pattern: ${public_pattern}")
    endif()
endforeach()

foreach(private_pattern IN ITEMS "amcl::" "librobot_detail::AMCLAdapter")
    if(symbols MATCHES "${private_pattern}")
        message(FATAL_ERROR
            "The installed shared library exports private symbol pattern: ${private_pattern}")
    endif()
endforeach()

message(STATUS "Verified public librobot ABI and hidden AMCL implementation symbols")

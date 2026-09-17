foreach(required_variable IN ITEMS
        LIBROBOT_MACOS_PERMISSIONS_HOOK
        LIBROBOT_TEST_DIRECTORY)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "${required_variable} is required")
    endif()
endforeach()

file(REMOVE_RECURSE "${LIBROBOT_TEST_DIRECTORY}")
file(MAKE_DIRECTORY "${LIBROBOT_TEST_DIRECTORY}")
foreach(script_name IN ITEMS install.sh uninstall.sh)
    file(WRITE "${LIBROBOT_TEST_DIRECTORY}/${script_name}" "#!/bin/sh\n")
    if(UNIX)
        execute_process(
            COMMAND /bin/chmod 644
                "${LIBROBOT_TEST_DIRECTORY}/${script_name}"
            COMMAND_ERROR_IS_FATAL ANY)
    else()
        file(CHMOD "${LIBROBOT_TEST_DIRECTORY}/${script_name}"
            PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
    endif()
endforeach()

set(CPACK_TEMPORARY_INSTALL_DIRECTORY "${LIBROBOT_TEST_DIRECTORY}")
include("${LIBROBOT_MACOS_PERMISSIONS_HOOK}")

if(APPLE)
    foreach(script_name IN ITEMS install.sh uninstall.sh)
        execute_process(
            COMMAND /usr/bin/stat -f %A
                "${LIBROBOT_TEST_DIRECTORY}/${script_name}"
            RESULT_VARIABLE stat_result
            OUTPUT_VARIABLE script_mode
            ERROR_VARIABLE stat_error
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(NOT stat_result EQUAL 0 OR NOT script_mode STREQUAL "755")
            message(FATAL_ERROR
                "The macOS permission hook set ${script_name} mode to "
                "'${script_mode}', expected 755: ${stat_error}")
        endif()
    endforeach()
elseif(UNIX)
    foreach(script_name IN ITEMS install.sh uninstall.sh)
        execute_process(
            COMMAND /usr/bin/test -x
                "${LIBROBOT_TEST_DIRECTORY}/${script_name}"
            RESULT_VARIABLE script_result)
        if(NOT script_result EQUAL 0)
            message(FATAL_ERROR
                "The macOS permission hook did not make ${script_name} executable")
        endif()
    endforeach()
endif()

file(REMOVE_RECURSE "${LIBROBOT_TEST_DIRECTORY}")

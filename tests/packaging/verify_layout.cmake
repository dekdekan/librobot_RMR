if(NOT DEFINED LIBROBOT_PACKAGE_FILE OR
        NOT EXISTS "${LIBROBOT_PACKAGE_FILE}")
    message(FATAL_ERROR
        "LIBROBOT_PACKAGE_FILE must name the exact generated package")
endif()
if(NOT DEFINED LIBROBOT_EXTRACT_DIRECTORY)
    message(FATAL_ERROR "LIBROBOT_EXTRACT_DIRECTORY is required")
endif()

file(MAKE_DIRECTORY "${LIBROBOT_EXTRACT_DIRECTORY}")
if(LIBROBOT_PACKAGE_FORMAT STREQUAL "DEB")
    if(NOT DEFINED LIBROBOT_DPKG_DEB OR
            NOT EXISTS "${LIBROBOT_DPKG_DEB}")
        message(FATAL_ERROR "LIBROBOT_DPKG_DEB is required for DEB inspection")
    endif()
    execute_process(
        COMMAND "${LIBROBOT_DPKG_DEB}" --extract
            "${LIBROBOT_PACKAGE_FILE}" "${LIBROBOT_EXTRACT_DIRECTORY}"
        RESULT_VARIABLE extract_result
        ERROR_VARIABLE extract_error)
    if(NOT extract_result EQUAL 0)
        message(FATAL_ERROR
            "Could not extract ${LIBROBOT_PACKAGE_FILE}: ${extract_error}")
    endif()
elseif(LIBROBOT_PACKAGE_FORMAT STREQUAL "TGZ")
    execute_process(
        COMMAND /usr/bin/tar -xzf "${LIBROBOT_PACKAGE_FILE}"
            -C "${LIBROBOT_EXTRACT_DIRECTORY}"
        RESULT_VARIABLE extract_result
        ERROR_VARIABLE extract_error)
    if(NOT extract_result EQUAL 0)
        message(FATAL_ERROR
            "Could not extract ${LIBROBOT_PACKAGE_FILE}: ${extract_error}")
    endif()
else()
    file(ARCHIVE_EXTRACT
        INPUT "${LIBROBOT_PACKAGE_FILE}"
        DESTINATION "${LIBROBOT_EXTRACT_DIRECTORY}")
endif()

set(package_root "${LIBROBOT_EXTRACT_DIRECTORY}")
if(DEFINED LIBROBOT_LAYOUT_PREFIX AND NOT LIBROBOT_LAYOUT_PREFIX STREQUAL "")
    string(APPEND package_root "/${LIBROBOT_LAYOUT_PREFIX}")
endif()

function(require_package_entry entry)
    if(NOT EXISTS "${package_root}/${entry}")
        message(FATAL_ERROR
            "Package ${LIBROBOT_PACKAGE_FILE} is missing ${entry}")
    endif()
endfunction()

require_package_entry("lib")
require_package_entry("include/librobot")
require_package_entry("lib/cmake/librobot/librobotConfig.cmake")

if(LIBROBOT_REQUIRE_BIN)
    require_package_entry("bin")
endif()

if(LIBROBOT_REQUIRE_WINDOWS_CONFIGS)
    require_package_entry("bin/librobot.dll")
    require_package_entry("bin/librobot_d.dll")
    require_package_entry("lib/librobot.lib")
    require_package_entry("lib/librobot_d.lib")
endif()

if(LIBROBOT_REQUIRE_MACOS_SCRIPTS)
    require_package_entry("install.sh")
    require_package_entry("uninstall.sh")
    execute_process(COMMAND /usr/bin/test -x "${package_root}/install.sh"
        RESULT_VARIABLE install_script_result)
    execute_process(COMMAND /usr/bin/test -x "${package_root}/uninstall.sh"
        RESULT_VARIABLE uninstall_script_result)
    if(NOT install_script_result EQUAL 0 OR NOT uninstall_script_result EQUAL 0)
        message(FATAL_ERROR "macOS package scripts are not executable")
    endif()
endif()

file(GLOB_RECURSE package_entries
    LIST_DIRECTORIES TRUE
    RELATIVE "${package_root}"
    "${package_root}/*")
set(librobot_public_headers
    include/librobot/amcl_types.h
    include/librobot/ckobuki.h
    include/librobot/librobot.h
    include/librobot/robot_global.h
    include/librobot/rplidar.h
    include/librobot/skeleton.h
    include/librobot/szevent.h
    include/librobot/udp_communication.h)
foreach(package_entry IN LISTS package_entries)
    file(TO_CMAKE_PATH "${package_entry}" package_entry)
    string(TOLOWER "${package_entry}" package_entry_lower)
    if(package_entry_lower MATCHES
            "(^|/)[^/]*amcl[^/]*\\.(dll|dylib|lib|a|so(\\.[0-9]+)*)$")
        message(FATAL_ERROR
            "Package ${LIBROBOT_PACKAGE_FILE} contains a separate AMCL library: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES "(^|/)amcl[^/]*/")
        message(FATAL_ERROR
            "Package ${LIBROBOT_PACKAGE_FILE} leaks private AMCL paths: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES
            "(^|/)(lib)?(qt(5|6)|opencv)[^/]*\\.(dll|dylib|lib|a|so(\\.[0-9]+)*)$")
        message(FATAL_ERROR
            "Package ${LIBROBOT_PACKAGE_FILE} bundles a Qt/OpenCV library: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES "(^|/)(opencv2|qtcore|qtnetwork)(/|$)")
        message(FATAL_ERROR
            "Package ${LIBROBOT_PACKAGE_FILE} bundles Qt/OpenCV headers: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES "\\.(h|hh|hpp|hxx)$")
        list(FIND librobot_public_headers "${package_entry_lower}" public_header_index)
        if(public_header_index EQUAL -1)
            message(FATAL_ERROR
                "Package ${LIBROBOT_PACKAGE_FILE} contains a non-public header: ${package_entry}")
        endif()
    endif()
endforeach()

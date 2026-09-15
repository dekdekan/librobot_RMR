if(NOT DEFINED LIBROBOT_PACKAGE_DIRECTORY)
    message(FATAL_ERROR "LIBROBOT_PACKAGE_DIRECTORY is required")
endif()

file(GLOB package_files "${LIBROBOT_PACKAGE_DIRECTORY}/*.zip")
list(LENGTH package_files package_count)
if(NOT package_count EQUAL 1)
    message(FATAL_ERROR
        "Expected exactly one librobot ZIP package in ${LIBROBOT_PACKAGE_DIRECTORY}; "
        "found ${package_count}")
endif()

list(GET package_files 0 package_file)
set(extract_directory "${LIBROBOT_PACKAGE_DIRECTORY}/layout-check")
file(REMOVE_RECURSE "${extract_directory}")
file(MAKE_DIRECTORY "${extract_directory}")
file(ARCHIVE_EXTRACT INPUT "${package_file}" DESTINATION "${extract_directory}")

function(require_package_entry entry)
    if(NOT EXISTS "${extract_directory}/${entry}")
        message(FATAL_ERROR "Package ${package_file} is missing ${entry}")
    endif()
endfunction()

require_package_entry("bin")
require_package_entry("lib")
require_package_entry("include/librobot")
require_package_entry("lib/cmake/librobot/librobotConfig.cmake")

if(WIN32)
    require_package_entry("bin/librobot.dll")
    require_package_entry("bin/librobot_d.dll")
    require_package_entry("lib/librobot.lib")
    require_package_entry("lib/librobot_d.lib")
endif()

file(GLOB_RECURSE package_entries
    LIST_DIRECTORIES TRUE
    RELATIVE "${extract_directory}"
    "${extract_directory}/*")
foreach(package_entry IN LISTS package_entries)
    file(TO_CMAKE_PATH "${package_entry}" package_entry)
    string(TOLOWER "${package_entry}" package_entry_lower)
    if(package_entry_lower MATCHES
            "(^|/)[^/]*amcl[^/]*\\.(dll|so|dylib|lib|a)$")
        message(FATAL_ERROR
            "Package ${package_file} contains a separate AMCL library: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES "(^|/)(amcl|amcl-build)(/|$)")
        message(FATAL_ERROR
            "Package ${package_file} leaks private AMCL paths: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES
            "(^|/)(lib)?(qt(5|6)|opencv)[^/]*\\.(dll|so|dylib|lib|a)$")
        message(FATAL_ERROR
            "Package ${package_file} bundles a Qt/OpenCV library: ${package_entry}")
    endif()
    if(package_entry_lower MATCHES "(^|/)(opencv2|qtcore|qtnetwork)(/|$)")
        message(FATAL_ERROR
            "Package ${package_file} bundles Qt/OpenCV headers: ${package_entry}")
    endif()
endforeach()

file(REMOVE_RECURSE "${extract_directory}")

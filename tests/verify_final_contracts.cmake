foreach(required_variable IN ITEMS
        LIBROBOT_SOURCE_CMAKE
        LIBROBOT_ROOT_CMAKE
        LIBROBOT_README
        LIBROBOT_CI_WORKFLOW
        LIBROBOT_RELEASE_WORKFLOW)
    if(NOT DEFINED ${required_variable})
        message(FATAL_ERROR "Missing required variable ${required_variable}")
    endif()
endforeach()

file(READ "${LIBROBOT_SOURCE_CMAKE}" source_cmake)
file(READ "${LIBROBOT_ROOT_CMAKE}" root_cmake)
file(READ "${LIBROBOT_README}" readme)
file(READ "${LIBROBOT_CI_WORKFLOW}" ci_workflow)
file(READ "${LIBROBOT_RELEASE_WORKFLOW}" release_workflow)

foreach(required_fragment IN ITEMS
        "CXX_VISIBILITY_PRESET hidden"
        "VISIBILITY_INLINES_HIDDEN YES"
        "--exclude-libs,ALL")
    if(NOT source_cmake MATCHES "${required_fragment}")
        message(FATAL_ERROR
            "The shared-library symbol boundary is missing: ${required_fragment}")
    endif()
endforeach()

foreach(workflow_content IN ITEMS "${ci_workflow}" "${release_workflow}")
    if(NOT workflow_content MATCHES "brew install opencv@4 ninja")
        message(FATAL_ERROR
            "macOS dependency setup must install the supported OpenCV 4 formula")
    endif()
    if(NOT workflow_content MATCHES "brew --prefix opencv@4")
        message(FATAL_ERROR
            "macOS OpenCV paths must use the versioned OpenCV 4 formula")
    endif()
    if(NOT workflow_content MATCHES "find -H")
        message(FATAL_ERROR
            "macOS OpenCV discovery must follow Homebrew's opt-prefix symlink")
    endif()
endforeach()
if(NOT root_cmake MATCHES
        "set_target_properties\\(amcl PROPERTIES[^)]*CXX_VISIBILITY_PRESET hidden")
    message(FATAL_ERROR "The embedded AMCL target is not compiled with hidden visibility")
endif()

if(readme MATCHES "apt install qt6-base-dev")
    message(FATAL_ERROR
        "Ubuntu instructions still select Qt 6.4 instead of the supported Qt 6.8.x line")
endif()
foreach(required_fragment IN ITEMS
        "official Qt Online Installer"
        "LIBROBOT_QT_ROOT"
        "librobot_AMCL_ENABLED"
        "librobot_OPENCV_ENABLED")
    if(NOT readme MATCHES "${required_fragment}")
        message(FATAL_ERROR "README contract is missing: ${required_fragment}")
    endif()
endforeach()

foreach(required_fragment IN ITEMS
        "VerifyExportedSymbols.cmake"
        "LIBROBOT_QT_ROOT")
    if(NOT release_workflow MATCHES "${required_fragment}")
        message(FATAL_ERROR "Release verification is missing: ${required_fragment}")
    endif()
endforeach()

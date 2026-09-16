if(NOT DEFINED CPACK_TEMPORARY_INSTALL_DIRECTORY)
    message(FATAL_ERROR
        "CPACK_TEMPORARY_INSTALL_DIRECTORY is required for macOS packaging")
endif()

foreach(script_name IN ITEMS install.sh uninstall.sh)
    set(script_path
        "${CPACK_TEMPORARY_INSTALL_DIRECTORY}/${script_name}")
    if(NOT EXISTS "${script_path}")
        message(FATAL_ERROR
            "macOS package staging is missing ${script_name}: ${script_path}")
    endif()
    file(CHMOD "${script_path}"
        PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE)
endforeach()

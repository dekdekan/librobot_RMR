include_guard(GLOBAL)

set(CPACK_PACKAGE_NAME "librobot")
set(CPACK_PACKAGE_VENDOR "librobot")
set(CPACK_PACKAGE_CONTACT "librobot maintainers")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "librobot runtime and CMake development package")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packages")
set(CPACK_VERBATIM_VARIABLES ON)

if(WIN32)
    # CPack installs Release normally.  Stage Debug first so the installer and
    # ZIP expose both MSVC runtime/import-library mappings from one package.
    set(LIBROBOT_CPACK_DEBUG_BUILD_DIR "${CMAKE_BINARY_DIR}" CACHE PATH
        "Build directory containing the Debug librobot install tree for CPack")
    set(_librobot_cpack_debug_install_script
        "${CMAKE_BINARY_DIR}/CPackInstallDebug.cmake")
    file(WRITE "${_librobot_cpack_debug_install_script}"
        "execute_process(\n"
        "    COMMAND \"${CMAKE_COMMAND}\" --install \"${LIBROBOT_CPACK_DEBUG_BUILD_DIR}\"\n"
        "        --config Debug --prefix \"\${CMAKE_INSTALL_PREFIX}\"\n"
        "    RESULT_VARIABLE install_result\n"
        ")\n"
        "if(NOT install_result EQUAL 0)\n"
        "    message(FATAL_ERROR \"CPack Debug staging install failed (\${install_result})\")\n"
        "endif()\n")

    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_INSTALL_SCRIPTS "${_librobot_cpack_debug_install_script}")
    set(CPACK_BUILD_CONFIG Release)
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "librobot")
    set(CPACK_NSIS_INSTALL_ROOT "$LOCALAPPDATA")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_MODIFY_PATH OFF)
    set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS [=[
WriteRegExpandStr HKCU "Environment" "LIBROBOT_ROOT" "$INSTDIR"
StrCpy $ADD_TO_PATH_ALL_USERS 0
Push "$INSTDIR\bin"
Call AddToPath
]=])
    set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS [=[
DeleteRegValue HKCU "Environment" "LIBROBOT_ROOT"
StrCpy $ADD_TO_PATH_ALL_USERS 0
Push "$INSTDIR\bin"
Call un.RemoveFromPath
]=])
elseif(APPLE)
    set(CPACK_GENERATOR "TGZ")
    set(CPACK_BUILD_CONFIG Release)
    set(CPACK_PACKAGING_INSTALL_PREFIX "/")
    install(PROGRAMS
        "${PROJECT_SOURCE_DIR}/packaging/macos/install.sh"
        "${PROJECT_SOURCE_DIR}/packaging/macos/uninstall.sh"
        DESTINATION .)
else()
    set(CPACK_GENERATOR "DEB;TGZ")
    set(CPACK_BUILD_CONFIG Release)
    set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
endif()

include(CPack)

if(BUILD_TESTING AND WIN32)
    add_test(
        NAME package.layout
        COMMAND "${CMAKE_COMMAND}"
            "-DLIBROBOT_PACKAGE_DIRECTORY=${CPACK_PACKAGE_DIRECTORY}"
            -P "${PROJECT_SOURCE_DIR}/tests/packaging/verify_layout.cmake"
    )
endif()

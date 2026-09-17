include_guard(GLOBAL)

set(CPACK_PACKAGE_NAME "librobot")
set(CPACK_PACKAGE_VENDOR "librobot")
set(CPACK_PACKAGE_CONTACT "librobot maintainers")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "librobot runtime and CMake development package")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
if(WIN32 AND CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(_librobot_package_system_name win64)
elseif(WIN32)
    set(_librobot_package_system_name win32)
else()
    set(_librobot_package_system_name "${CMAKE_SYSTEM_NAME}")
endif()
set(CPACK_PACKAGE_FILE_NAME
    "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${_librobot_package_system_name}")
set(_librobot_binary_package_file_name "${CPACK_PACKAGE_FILE_NAME}")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/packages")
set(CPACK_VERBATIM_VARIABLES ON)

if(WIN32)
    set(_librobot_nsis_module_directory
        "${CMAKE_BINARY_DIR}/librobot-cpack-modules")
    set(_librobot_nsis_template
        "${_librobot_nsis_module_directory}/NSIS.template.in")
    file(MAKE_DIRECTORY "${_librobot_nsis_module_directory}")
    set(_librobot_stock_nsis_template
        "${CMAKE_ROOT}/Modules/Internal/CPack/NSIS.template.in")
    if(NOT EXISTS "${_librobot_stock_nsis_template}")
        set(_librobot_stock_nsis_template
            "${CMAKE_ROOT}/Modules/NSIS.template.in")
    endif()
    if(NOT EXISTS "${_librobot_stock_nsis_template}")
        message(FATAL_ERROR "Could not locate CPack's NSIS.template.in")
    endif()
    include("${CMAKE_CURRENT_LIST_DIR}/CustomizeNsisTemplate.cmake")
    librobot_customize_nsis_template(
        "${_librobot_stock_nsis_template}" "${_librobot_nsis_template}")
    list(PREPEND CPACK_MODULE_PATH "${_librobot_nsis_module_directory}")

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
    set(CPACK_PRE_BUILD_SCRIPTS
        "${CMAKE_CURRENT_LIST_DIR}/FixMacosPackagePermissions.cmake")
else()
    set(CPACK_GENERATOR "DEB;TGZ")
    set(CPACK_BUILD_CONFIG Release)
    set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_DEBIAN_FILE_NAME "${CPACK_PACKAGE_FILE_NAME}.deb")
endif()

include(CPack)

if(BUILD_TESTING)
    set(_librobot_package_test_directory
        "${PROJECT_SOURCE_DIR}/tests/packaging")

    function(_librobot_add_package_layout_test
            test_name generator extension format layout_prefix
            require_bin require_windows_configs require_macos_scripts)
        string(TOLOWER "${generator}" generator_lower)
        add_test(
            NAME "${test_name}"
            COMMAND "${CMAKE_COMMAND}"
                "-DLIBROBOT_CPACK_COMMAND=${CMAKE_CPACK_COMMAND}"
                "-DLIBROBOT_CPACK_CONFIG=${CPACK_OUTPUT_CONFIG_FILE}"
                "-DLIBROBOT_PACKAGE_GENERATOR=${generator}"
                "-DLIBROBOT_PACKAGE_FILE=${CPACK_PACKAGE_DIRECTORY}/${_librobot_binary_package_file_name}${extension}"
                "-DLIBROBOT_EXTRACT_DIRECTORY=${CMAKE_BINARY_DIR}/package-layout-${generator_lower}"
                "-DLIBROBOT_PACKAGE_FORMAT=${format}"
                "-DLIBROBOT_LAYOUT_PREFIX=${layout_prefix}"
                "-DLIBROBOT_REQUIRE_BIN=${require_bin}"
                "-DLIBROBOT_REQUIRE_WINDOWS_CONFIGS=${require_windows_configs}"
                "-DLIBROBOT_REQUIRE_MACOS_SCRIPTS=${require_macos_scripts}"
                "-DLIBROBOT_DPKG_DEB=${_librobot_dpkg_deb}"
                -DLIBROBOT_VERIFY_LAYOUT=TRUE
                "-DLIBROBOT_VERIFY_SCRIPT=${_librobot_package_test_directory}/verify_layout.cmake"
                -P "${_librobot_package_test_directory}/generate_and_verify.cmake")
    endfunction()

    if(WIN32)
        _librobot_add_package_layout_test(
            package.layout.zip ZIP .zip ARCHIVE "" TRUE TRUE FALSE)
        add_test(
            NAME package.nsis_template
            COMMAND "${CMAKE_COMMAND}"
                "-DLIBROBOT_NSIS_TEMPLATE=${_librobot_nsis_template}"
                "-DLIBROBOT_NSIS_TEST_DIRECTORY=${CMAKE_BINARY_DIR}/package-nsis-template"
                -P "${_librobot_package_test_directory}/verify_nsis_template.cmake")
        add_test(
            NAME package.nsis_template.cmake_3_31
            COMMAND "${CMAKE_COMMAND}"
                "-DLIBROBOT_NSIS_CUSTOMIZER=${PROJECT_SOURCE_DIR}/cmake/CustomizeNsisTemplate.cmake"
                "-DLIBROBOT_NSIS_STOCK_TEMPLATE=${_librobot_package_test_directory}/NSIS.cmake-3.31.template.in"
                "-DLIBROBOT_NSIS_OUTPUT_TEMPLATE=${CMAKE_BINARY_DIR}/NSIS.cmake-3.31.customized.in"
                "-DLIBROBOT_NSIS_TEST_DIRECTORY=${CMAKE_BINARY_DIR}/package-nsis-template-cmake-3.31"
                "-DLIBROBOT_NSIS_VERIFY_SCRIPT=${_librobot_package_test_directory}/verify_nsis_template.cmake"
                -P "${_librobot_package_test_directory}/verify_nsis_customization.cmake")

        find_program(_librobot_makensis makensis)
        if(_librobot_makensis)
            add_test(
                NAME package.generate.nsis
                COMMAND "${CMAKE_COMMAND}"
                    "-DLIBROBOT_CPACK_COMMAND=${CMAKE_CPACK_COMMAND}"
                    "-DLIBROBOT_CPACK_CONFIG=${CPACK_OUTPUT_CONFIG_FILE}"
                    -DLIBROBOT_PACKAGE_GENERATOR=NSIS
                    "-DLIBROBOT_PACKAGE_FILE=${CPACK_PACKAGE_DIRECTORY}/${_librobot_binary_package_file_name}.exe"
                    "-DLIBROBOT_EXTRACT_DIRECTORY=${CMAKE_BINARY_DIR}/package-layout-nsis"
                    -DLIBROBOT_VERIFY_LAYOUT=FALSE
                    -P "${_librobot_package_test_directory}/generate_and_verify.cmake")
        endif()
    elseif(APPLE)
        _librobot_add_package_layout_test(
            package.layout.tgz TGZ .tar.gz TGZ "" FALSE FALSE TRUE)
    else()
        find_program(_librobot_dpkg_deb dpkg-deb)
        _librobot_add_package_layout_test(
            package.layout.tgz TGZ .tar.gz TGZ usr FALSE FALSE FALSE)
        _librobot_add_package_layout_test(
            package.layout.deb DEB .deb DEB usr FALSE FALSE FALSE)
    endif()

    foreach(rejection_case IN ITEMS amcl-versioned opencv-versioned qt-versioned private-header)
        if(rejection_case STREQUAL "amcl-versioned")
            set(forbidden_path "lib/libamcl.so.1")
            set(expected_error "separate AMCL library")
        elseif(rejection_case STREQUAL "opencv-versioned")
            set(forbidden_path "lib/libopencv_core.so.4.10")
            set(expected_error "Qt/OpenCV library")
        elseif(rejection_case STREQUAL "qt-versioned")
            set(forbidden_path "lib/libQt6Core.so.6")
            set(expected_error "Qt/OpenCV library")
        else()
            set(forbidden_path "include/librobot/private/pf.h")
            set(expected_error "non-public header")
        endif()
        add_test(
            NAME "package.reject.${rejection_case}"
            COMMAND "${CMAKE_COMMAND}"
                "-DLIBROBOT_TEST_DIRECTORY=${CMAKE_BINARY_DIR}/package-reject-${rejection_case}"
                "-DLIBROBOT_FORBIDDEN_PATH=${forbidden_path}"
                "-DLIBROBOT_EXPECTED_ERROR=${expected_error}"
                "-DLIBROBOT_VERIFY_SCRIPT=${_librobot_package_test_directory}/verify_layout.cmake"
                -P "${_librobot_package_test_directory}/verify_rejection.cmake")
    endforeach()
endif()

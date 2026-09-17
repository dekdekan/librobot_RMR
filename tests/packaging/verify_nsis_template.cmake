if(NOT DEFINED LIBROBOT_NSIS_TEMPLATE OR
        NOT EXISTS "${LIBROBOT_NSIS_TEMPLATE}")
    message(FATAL_ERROR "LIBROBOT_NSIS_TEMPLATE must name an existing template")
endif()
if(NOT DEFINED LIBROBOT_NSIS_TEST_DIRECTORY)
    message(FATAL_ERROR "LIBROBOT_NSIS_TEST_DIRECTORY is required")
endif()

file(REMOVE_RECURSE "${LIBROBOT_NSIS_TEST_DIRECTORY}")
file(MAKE_DIRECTORY "${LIBROBOT_NSIS_TEST_DIRECTORY}")

set(CPACK_PACKAGE_VERSION "1.2.1")
set(CPACK_PACKAGE_VERSION_PATCH "1")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "librobot")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "librobot")
set(CPACK_NSIS_INSTALL_ROOT "$LOCALAPPDATA")
set(CPACK_NSIS_PACKAGE_NAME "librobot")
set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL "ON")
set(CPACK_NSIS_UNINSTALL_NAME "Uninstall")
set(CPACK_NSIS_MODIFY_PATH "OFF")
configure_file(
    "${LIBROBOT_NSIS_TEMPLATE}"
    "${LIBROBOT_NSIS_TEST_DIRECTORY}/project.nsi"
    @ONLY)

file(READ "${LIBROBOT_NSIS_TEST_DIRECTORY}/project.nsi" nsis_script)

function(extract_nsis_function function_name output_variable)
    string(FIND "${nsis_script}" "Function ${function_name}" function_index)
    if(function_index EQUAL -1)
        message(FATAL_ERROR "Generated project.nsi is missing Function ${function_name}")
    endif()
    string(SUBSTRING "${nsis_script}" ${function_index} -1 function_tail)
    string(FIND "${function_tail}" "FunctionEnd" function_end_index)
    if(function_end_index EQUAL -1)
        message(FATAL_ERROR "Function ${function_name} has no FunctionEnd")
    endif()
    string(LENGTH "FunctionEnd" function_end_length)
    math(EXPR function_length "${function_end_index} + ${function_end_length}")
    string(SUBSTRING "${function_tail}" 0 ${function_length} function_body)
    set(${output_variable} "${function_body}" PARENT_SCOPE)
endfunction()

function(require_nsis_command script_variable command description)
    string(FIND "${${script_variable}}" "${command}" command_index)
    if(command_index EQUAL -1)
        message(FATAL_ERROR
            "Generated project.nsi does not ${description}: ${command}")
    endif()
endfunction()

extract_nsis_function(".onInit" installer_on_init)
extract_nsis_function("un.onInit" uninstaller_on_init)
extract_nsis_function("AddToPath" add_to_path)

require_nsis_command(nsis_script "RequestExecutionLevel user"
    "run without machine-wide elevation")
require_nsis_command(installer_on_init
    "ReadRegStr $0 HKCU \"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\librobot\" \"UninstallString\""
    "discover the prior current-user uninstaller")
require_nsis_command(installer_on_init "ExecWait '\"$0\" /S _?=$3'"
    "execute the discovered prior uninstaller")
require_nsis_command(installer_on_init "StrCpy $INSTDIR \"$LOCALAPPDATA\\librobot\""
    "select the required current-user install directory")
require_nsis_command(installer_on_init "SetShellVarContext current"
    "keep shell and SHCTX registry writes current-user scoped")
require_nsis_command(installer_on_init "StrCpy $SV_ALLUSERS \"JustMe\""
    "fix the installer mode to current-user")
require_nsis_command(uninstaller_on_init "SetShellVarContext current"
    "keep uninstaller registry cleanup current-user scoped")
require_nsis_command(add_to_path
    "ReadRegStr $1 HKCU \"Environment\" \"PATH\""
    "read the current-user PATH instead of the potentially oversized process PATH")

string(FIND "${add_to_path}" "ReadEnvStr $1 PATH" process_path_index)
if(NOT process_path_index EQUAL -1)
    message(FATAL_ERROR
        "Generated project.nsi still reads the process PATH before updating HKCU")
endif()

string(FIND "${installer_on_init}" "$DOCUMENTS\\librobot" documents_index)
if(NOT documents_index EQUAL -1)
    message(FATAL_ERROR
        "Generated project.nsi still redirects a current-user install to Documents")
endif()

string(FIND "${nsis_script}"
    "HKLM \"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\librobot"
    machine_uninstall_key_index)
if(NOT machine_uninstall_key_index EQUAL -1)
    message(FATAL_ERROR
        "Generated project.nsi still accesses librobot uninstall state in HKLM")
endif()

file(REMOVE_RECURSE "${LIBROBOT_NSIS_TEST_DIRECTORY}")

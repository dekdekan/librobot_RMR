include_guard(GLOBAL)

function(_librobot_count_nsis_template_fragments
        contents fragment output_variable)
    set(remaining "${contents}")
    set(actual_count 0)
    while(1)
        string(FIND "${remaining}" "${fragment}" match_index)
        if(match_index EQUAL -1)
            break()
        endif()
        math(EXPR actual_count "${actual_count} + 1")
        string(LENGTH "${fragment}" fragment_length)
        math(EXPR next_index "${match_index} + ${fragment_length}")
        string(SUBSTRING "${remaining}" ${next_index} -1 remaining)
    endwhile()
    set(${output_variable} "${actual_count}" PARENT_SCOPE)
endfunction()

function(_librobot_replace_nsis_template
        contents_variable original replacement expected_count description)
    _librobot_count_nsis_template_fragments(
        "${${contents_variable}}" "${original}" actual_count)
    if(NOT actual_count EQUAL expected_count)
        message(FATAL_ERROR
            "Cannot customize the CPack NSIS template: expected ${expected_count} "
            "${description} fragment(s), found ${actual_count}")
    endif()
    string(REPLACE "${original}" "${replacement}" updated_contents
        "${${contents_variable}}")
    set(${contents_variable} "${updated_contents}" PARENT_SCOPE)
endfunction()

function(_librobot_require_nsis_template
        contents fragment expected_count description)
    _librobot_count_nsis_template_fragments(
        "${contents}" "${fragment}" actual_count)
    if(NOT actual_count EQUAL expected_count)
        message(FATAL_ERROR
            "Cannot customize the CPack NSIS template: expected ${expected_count} "
            "${description} fragment(s), found ${actual_count}")
    endif()
endfunction()

function(librobot_customize_nsis_template input_template output_template)
    if(NOT EXISTS "${input_template}")
        message(FATAL_ERROR "CPack NSIS template does not exist: ${input_template}")
    endif()

    file(READ "${input_template}" nsis_template_contents)
    string(REPLACE "\r\n" "\n" nsis_template_contents
        "${nsis_template_contents}")

    _librobot_replace_nsis_template(nsis_template_contents
        "RequestExecutionLevel admin" "RequestExecutionLevel user" 1
        "execution-level")
    _librobot_replace_nsis_template(nsis_template_contents
        "SetShellVarContext all" "SetShellVarContext current" 4
        "shell-context")
    _librobot_replace_nsis_template(nsis_template_contents
        [=[ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@" "UninstallString"]=]
        [=[ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@" "UninstallString"]=]
        1 "upgrade-uninstaller registry")

    set(legacy_display_name_read
        [=[ReadRegStr $1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@" "DisplayName"]=])
    _librobot_count_nsis_template_fragments(
        "${nsis_template_contents}" "${legacy_display_name_read}"
        legacy_display_name_count)
    if(legacy_display_name_count EQUAL 1)
        _librobot_replace_nsis_template(nsis_template_contents
            "${legacy_display_name_read}"
            [=[ReadRegStr $1 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@" "DisplayName"]=]
            1 "upgrade-display-name registry")
    elseif(legacy_display_name_count EQUAL 0)
        _librobot_require_nsis_template(
            "${nsis_template_contents}"
            [=["@CPACK_NSIS_PACKAGE_NAME@ is already installed.]=]
            1 "CMake 3.31 upgrade package-name")
    else()
        message(FATAL_ERROR
            "Cannot customize the CPack NSIS template: expected at most 1 "
            "upgrade-display-name registry fragment, found ${legacy_display_name_count}")
    endif()

    _librobot_replace_nsis_template(nsis_template_contents
        [=[HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@\Components\${SecName}"]=]
        [=[HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\@CPACK_PACKAGE_INSTALL_REGISTRY_KEY@\Components\${SecName}"]=]
        3 "component registry")
    _librobot_replace_nsis_template(nsis_template_contents
        [=[StrCpy $INSTDIR "$DOCUMENTS\@CPACK_PACKAGE_INSTALL_DIRECTORY@"]=]
        [=[StrCpy $INSTDIR "$LOCALAPPDATA\@CPACK_PACKAGE_INSTALL_DIRECTORY@"]=]
        1 "current-user install-directory")
    _librobot_replace_nsis_template(nsis_template_contents
        "  noOptionsPage:\nFunctionEnd"
        "  noOptionsPage:\n  SetShellVarContext current\n  StrCpy $SV_ALLUSERS \"JustMe\"\n  StrCpy $INSTDIR \"$LOCALAPPDATA\\@CPACK_PACKAGE_INSTALL_DIRECTORY@\"\nFunctionEnd"
        1 "installer final current-user scope")
    _librobot_replace_nsis_template(nsis_template_contents
        "Function un.onInit\n\n  ClearErrors"
        "Function un.onInit\n\n  SetShellVarContext current\n  ClearErrors"
        1 "uninstaller current-user scope")

    get_filename_component(output_directory "${output_template}" DIRECTORY)
    file(MAKE_DIRECTORY "${output_directory}")
    file(WRITE "${output_template}" "${nsis_template_contents}")
endfunction()

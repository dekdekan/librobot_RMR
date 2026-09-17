if(NOT DEFINED CONFIG_FILE OR NOT DEFINED EXPECT_OPENCV OR
        NOT DEFINED EXPECT_SKELETON)
    message(FATAL_ERROR
        "CONFIG_FILE, EXPECT_OPENCV, and EXPECT_SKELETON are required.")
endif()

file(READ "${CONFIG_FILE}" config_contents)
string(REPLACE "\r\n" "\n" config_contents "${config_contents}")

if(EXPECT_SKELETON)
    string(FIND "${config_contents}" "set(librobot_SKELETON_ENABLED TRUE)" skeleton_value_index)
else()
    string(FIND "${config_contents}" "set(librobot_SKELETON_ENABLED FALSE)" skeleton_value_index)
endif()
if(skeleton_value_index EQUAL -1)
    message(FATAL_ERROR
        "Generated configuration has incorrect literal skeleton metadata.")
endif()

string(FIND "${config_contents}" "find_dependency(Qt6 6.5 REQUIRED COMPONENTS Core Network)" qt_dependency_index)
if(qt_dependency_index EQUAL -1)
    message(FATAL_ERROR "Generated librobotConfig.cmake must retain the exact Qt dependency.")
endif()

string(FIND "${config_contents}" "find_dependency(OpenCV 4 REQUIRED COMPONENTS" opencv_dependency_index)
if(opencv_dependency_index EQUAL -1)
    message(FATAL_ERROR "Generated librobotConfig.cmake must retain the exact OpenCV dependency branch.")
endif()

if(EXPECT_OPENCV)
    string(FIND "${config_contents}" "set(librobot_OPENCV_ENABLED TRUE)" feature_value_index)
    string(FIND "${config_contents}" "if(librobot_OPENCV_ENABLED)" feature_guard_index)
    if(feature_value_index EQUAL -1)
        message(FATAL_ERROR "OpenCV-enabled configuration must publish literal TRUE metadata.")
    endif()
    if(feature_guard_index EQUAL -1)
        message(FATAL_ERROR "OpenCV-enabled configuration must activate the OpenCV dependency branch.")
    endif()
else()
    string(FIND "${config_contents}" "set(librobot_OPENCV_ENABLED FALSE)" feature_value_index)
    if(feature_value_index EQUAL -1)
        message(FATAL_ERROR "OpenCV-disabled configuration must publish literal FALSE metadata.")
    endif()
endif()

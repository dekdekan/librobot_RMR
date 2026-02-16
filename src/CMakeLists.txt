set(LIBROBOT_SOURCES
    CKobuki.cpp
    librobot.cpp
    rplidar.cpp
    udp_communication.cpp
)

if(NOT LIBROBOT_DISABLE_SKELETON)
    list(APPEND LIBROBOT_SOURCES skeleton.cpp)
endif()

add_library(librobot SHARED ${LIBROBOT_SOURCES})
add_library(librobot::librobot ALIAS librobot)

target_include_directories(librobot
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>
        $<INSTALL_INTERFACE:include>
)

target_compile_definitions(librobot PRIVATE
    ROBOT_LIBRARY
)

if(LIBROBOT_DISABLE_SKELETON)
    target_compile_definitions(librobot PUBLIC DISABLE_SKELETON)
endif()

if(NOT LIBROBOT_DISABLE_OPENCV)
    find_package(OpenCV REQUIRED)
    target_link_libraries(librobot PUBLIC ${OpenCV_LIBS})
else()
    target_compile_definitions(librobot PUBLIC DISABLE_OPENCV)
endif()



find_package(Qt6 REQUIRED COMPONENTS Core Network) 

target_link_libraries(librobot PUBLIC Qt6::Core Qt6::Network) 

if(WIN32)
    target_link_libraries(librobot PRIVATE ws2_32 Winmm)
endif()

set_target_properties(librobot PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    DEBUG_POSTFIX _d
)

install(TARGETS librobot
    EXPORT librobotTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

message(STATUS "Install directory: ${CMAKE_INSTALL_INCLUDEDIR}")
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
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

target_compile_features(librobot PUBLIC cxx_std_20)

target_compile_definitions(librobot PRIVATE
    ROBOT_LIBRARY
)

if(LIBROBOT_ENABLE_AMCL)
    target_sources(librobot PRIVATE amcl_adapter.cpp)
    target_compile_definitions(librobot PUBLIC LIBROBOT_HAS_AMCL=1)
    target_link_libraries(librobot PRIVATE amcl::amcl)
else()
    target_compile_definitions(librobot PUBLIC DISABLE_AMCL)
endif()

if(LIBROBOT_DISABLE_SKELETON)
    target_compile_definitions(librobot PUBLIC DISABLE_SKELETON)
else()
    target_compile_definitions(librobot PUBLIC LIBROBOT_HAS_SKELETON=1)
endif()

if(LIBROBOT_ENABLE_OPENCV)
    target_compile_definitions(librobot PUBLIC LIBROBOT_HAS_OPENCV=1)
    target_include_directories(librobot PUBLIC
        $<BUILD_INTERFACE:${OpenCV_INCLUDE_DIRS}>
    )
    target_link_libraries(librobot PUBLIC ${OpenCV_LIBS})
else()
    target_compile_definitions(librobot PUBLIC DISABLE_OPENCV)
endif()


find_package(Qt6 6.5 REQUIRED COMPONENTS Core Network)

if(WIN32 AND BUILD_TESTING)
    get_target_property(_librobot_qt_core_location
        Qt6::Core IMPORTED_LOCATION_DEBUG)
    if(NOT _librobot_qt_core_location)
        get_target_property(_librobot_qt_core_location
            Qt6::Core IMPORTED_LOCATION_RELEASE)
    endif()
    get_filename_component(_librobot_qt_runtime_dir
        "${_librobot_qt_core_location}" DIRECTORY)
    set(LIBROBOT_QT_RUNTIME_DIR "${_librobot_qt_runtime_dir}" PARENT_SCOPE)
endif()

target_link_libraries(librobot PUBLIC Qt6::Core Qt6::Network) 

if(WIN32)
    target_link_libraries(librobot PRIVATE ws2_32 Winmm)
endif()

set_target_properties(librobot PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    DEBUG_POSTFIX _d
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
)

if(LIBROBOT_ENABLE_AMCL AND UNIX AND NOT APPLE AND
        CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    # Prevent symbols from any linked static archive from entering the ELF
    # dynamic symbol table even if a dependency was built with default
    # visibility.  libRobot remains public through ROBOT_EXPORT.
    target_link_options(librobot PRIVATE "LINKER:--exclude-libs,ALL")
endif()

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

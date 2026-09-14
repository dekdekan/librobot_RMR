if(LIBROBOT_ENABLE_AMCL)
    add_library(librobot_public_api_test OBJECT public_api_test.cpp)
    target_link_libraries(librobot_public_api_test PRIVATE librobot::librobot)
endif()

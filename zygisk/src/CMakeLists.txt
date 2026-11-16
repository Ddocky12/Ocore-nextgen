cmake_minimum_required(VERSION 3.18)
project(ocore_zygisk LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(ocore_zygisk SHARED
    ocore_zygisk.cpp
)

target_compile_options(ocore_zygisk PRIVATE
    -Wall -Wextra -Werror -fvisibility=hidden -ffunction-sections -fdata-sections -O2
)

target_link_libraries(ocore_zygisk
    log
)

set_target_properties(ocore_zygisk PROPERTIES
    OUTPUT_NAME "arm64-v8a"
    PREFIX ""
)

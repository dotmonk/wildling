cmake_minimum_required(VERSION 3.16)
project(wildling_cpp VERSION 2.0.5 LANGUAGES CXX)

add_library(wildling
  src/token.cpp
  src/parse_pattern.cpp
  src/generator.cpp
  src/wildling.cpp
  src/template_json.cpp
)
target_include_directories(wildling PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
  $<INSTALL_INTERFACE:include>
)
target_compile_features(wildling PUBLIC cxx_std_17)

add_executable(wildling_cli src/cli.cpp)
target_link_libraries(wildling_cli PRIVATE wildling)
set_target_properties(wildling_cli PROPERTIES OUTPUT_NAME wildling)

install(TARGETS wildling wildling_cli
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
install(FILES
  src/wildling.hpp
  src/generator.hpp
  src/parse_pattern.hpp
  src/token.hpp
  src/template_json.hpp
  DESTINATION include/wildling
)

cmake_minimum_required(VERSION 3.16)
project(wildling_c VERSION 2.0.2 LANGUAGES C)

add_library(wildling
  src/util.c
  src/token.c
  src/parse_pattern.c
  src/generator.c
  src/wildling.c
  src/json.c
)
target_include_directories(wildling PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
  $<INSTALL_INTERFACE:include>
)
target_compile_features(wildling PUBLIC c_std_11)

add_executable(wildling_cli src/cli.c)
target_link_libraries(wildling_cli PRIVATE wildling)
set_target_properties(wildling_cli PROPERTIES OUTPUT_NAME wildling)

install(TARGETS wildling wildling_cli
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
install(FILES
  src/wildling.h
  src/generator.h
  src/parse_pattern.h
  src/token.h
  src/util.h
  src/json.h
  DESTINATION include/wildling
)

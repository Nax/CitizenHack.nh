# Makedefs
add_executable(
    makedefs
    "${CMAKE_SOURCE_DIR}/src/monst.c"
    "${CMAKE_SOURCE_DIR}/src/objects.c"
    "${CMAKE_SOURCE_DIR}/util/makedefs.c"
)
target_compile_definitions(makedefs PRIVATE FILE_PREFIX=1)
target_link_libraries(makedefs)

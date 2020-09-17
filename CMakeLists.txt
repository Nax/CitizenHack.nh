cmake_minimum_required(VERSION 3.10)
project(CitizenHack)

find_package(Curses REQUIRED)
find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)
find_package(ZLIB REQUIRED)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

set(GAME "nethack")
set(GAME_ARCHIVE "nhdat")

# Config
set(HACK_DIRECTORY      "${CMAKE_INSTALL_PREFIX}/lib/nethack"   CACHE PATH      "The HACKDIR")
set(HACK_DUMPLOG        ON                                      CACHE BOOL      "Enable the dumplog feature")
set(HACK_DUMPLOG_FILE   "/tmp/nethack.%n.%d.log"                CACHE STRING    "The dumplog file template")
set(HACK_DATABASE       ON                                      CACHE BOOL      "Enable the database file")
set(HACK_WIN_CURSES     ON                                      CACHE BOOL      "Enable ncurses graphics")

if (HACK_WIN_CURSES)
    set(SUGGESTED_HACK_WIN_DEFAULT "curses")
else()
    set(SUGGESTED_HACK_WIN_DEFAULT "tty")
endif()

set(HACK_WIN_DEFAULT     ${SUGGESTED_HACK_WIN_DEFAULT}          CACHE STRING    "The default window system to use")

macro(inject_config tgt)
    target_compile_definitions(${tgt} PRIVATE
        HACKDIR="${HACK_DIRECTORY}"
        DUMPLOG_FILE="${HACK_DUMPLOG_FILE}"
        DEFAULT_WINDOW_SYS="${HACK_WIN_DEFAULT}"
        $<$<BOOL:${HACK_DATABASE}>:DLB>
        $<$<BOOL:${HACK_DUMPLOG}>:DUMPLOG>
        $<$<BOOL:${HACK_WIN_CURSES}>:CURSES_GRAPHICS>
        SCORE_ON_BOTL
        SECURE
        ZLIB_COMP
    )
endmacro()

# Makedefs
add_executable(
    makedefs
    "${CMAKE_SOURCE_DIR}/src/monst.c"
    "${CMAKE_SOURCE_DIR}/src/objects.c"
    "${CMAKE_SOURCE_DIR}/util/makedefs.c"
)
inject_config(makedefs)
target_compile_definitions(makedefs PRIVATE FILE_PREFIX=1)
target_include_directories(makedefs PRIVATE "${CMAKE_SOURCE_DIR}/include")

set(GENERATED_DIR           "${CMAKE_BINARY_DIR}/gen")
set(GENERATED_DIR_DUMMY     "${GENERATED_DIR}/dummy")
set(HACKDIR                 "${CMAKE_BINARY_DIR}/hackdir")
if (HACK_DATABASE)
    set(HACKDIR_DATA "${CMAKE_BINARY_DIR}/hackdir_data")
else()
    set(HACKDIR_DATA "${HACKDIR}")
endif()

file(MAKE_DIRECTORY ${HACKDIR} ${HACKDIR_DATA} ${GENERATED_DIR_DUMMY} "${GENERATED_DIR}/include" "${GENERATED_DIR}/src" "${GENERATED_DIR}/dat" "${CMAKE_BINARY_DIR}/stamps/lev")

function(add_makedef flag)
    set(outputs "")
    foreach(o ${ARGN})
        list(APPEND outputs "${GENERATED_DIR}/${o}")
    endforeach()
    add_custom_command(
        OUTPUT ${outputs}
        COMMAND makedefs "${GENERATED_DIR_DUMMY}/" "-${flag}"
        VERBATIM
    )
endfunction()

add_makedef(d "dat/data")
add_makedef(p "include/pm.h")
add_makedef(o "include/onames.h")
add_makedef(v "include/date.h" "dat/options")
add_makedef(e "dat/dungeon.pdf")
add_makedef(q "dat/quest.dat")
add_makedef(s "dat/bogusmon" "dat/engrave" "dat/epitaph")
add_makedef(r "dat/rumors")
add_makedef(h "dat/oracles")

# Dungeon Compiler
bison_target(dgn_parser "${CMAKE_SOURCE_DIR}/util/dgn_comp.y" "${GENERATED_DIR}/src/dgn_parser.c" DEFINES_FILE "${GENERATED_DIR}/include/dgn_comp.h")
flex_target(dgn_lexer "${CMAKE_SOURCE_DIR}/util/dgn_comp.l" "${GENERATED_DIR}/src/dgn_lexer.c")
add_flex_bison_dependency(dgn_lexer dgn_parser)
add_executable(dgn
    "${CMAKE_SOURCE_DIR}/src/alloc.c"
    "${CMAKE_SOURCE_DIR}/util/panic.c"
    "${CMAKE_SOURCE_DIR}/util/dgn_main.c"
    "${GENERATED_DIR}/src/dgn_parser.c"
    "${GENERATED_DIR}/src/dgn_lexer.c"
    "${GENERATED_DIR}/include/date.h"
)
inject_config(dgn)
target_include_directories(dgn PRIVATE "${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include")

# Level Compiler
bison_target(lev_parser "${CMAKE_SOURCE_DIR}/util/lev_comp.y" "${GENERATED_DIR}/src/lev_parser.c" DEFINES_FILE "${GENERATED_DIR}/include/lev_comp.h")
flex_target(lev_lexer "${CMAKE_SOURCE_DIR}/util/lev_comp.l" "${GENERATED_DIR}/src/lev_lexer.c")
add_flex_bison_dependency(lev_lexer lev_parser)
add_executable(lev
    "${CMAKE_SOURCE_DIR}/src/alloc.c"
    "${CMAKE_SOURCE_DIR}/util/panic.c"
    "${CMAKE_SOURCE_DIR}/src/monst.c"
    "${CMAKE_SOURCE_DIR}/src/objects.c"
    "${CMAKE_SOURCE_DIR}/src/decl.c"
    "${CMAKE_SOURCE_DIR}/src/drawing.c"
    "${CMAKE_SOURCE_DIR}/util/lev_main.c"
    "${GENERATED_DIR}/src/lev_parser.c"
    "${GENERATED_DIR}/src/lev_lexer.c"
    "${GENERATED_DIR}/include/lev_comp.h"
    "${GENERATED_DIR}/include/date.h"
    "${GENERATED_DIR}/include/pm.h"
    "${GENERATED_DIR}/include/onames.h"
)
inject_config(lev)
target_include_directories(lev PRIVATE "${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include")

# Hackdir Data

# dungeon
set(HACKDIR_DATA_FILES "")
macro(copy_nhdat src)
    get_filename_component(_fname ${src} NAME)

    add_custom_command(
        OUTPUT "${HACKDIR_DATA}/${_fname}"
        DEPENDS "${src}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${src}" "${HACKDIR_DATA}/${_fname}"
        VERBATIM
    )
    list(APPEND HACKDIR_DATA_FILES ${_fname})
endmacro()
add_custom_command(
    OUTPUT "${HACKDIR_DATA}/dungeon"
    COMMAND dgn "${GENERATED_DIR}/dat/dungeon.pdf"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${GENERATED_DIR}/dat/dungeon" "${HACKDIR_DATA}/dungeon"
    DEPENDS "${GENERATED_DIR}/dat/dungeon.pdf"
    VERBATIM
)
list(APPEND HACKDIR_DATA_FILES dungeon)

# levels
file(GLOB_RECURSE LEVELS "${CMAKE_SOURCE_DIR}/dat/*.des")
set(STAMPS_LEVELS "")
foreach(l ${LEVELS})
    get_filename_component(fname ${l} NAME)
    add_custom_command(
        OUTPUT "${CMAKE_BINARY_DIR}/stamps/lev/${fname}.stamp"
        COMMAND lev "${l}"
        COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_BINARY_DIR}/stamps/lev/${fname}.stamp"
        DEPENDS "${l}"
        WORKING_DIRECTORY "${HACKDIR_DATA}"
        COMMENT "Compiling level ${l}"
        VERBATIM
    )
    list(APPEND STAMPS_LEVELS "${CMAKE_BINARY_DIR}/stamps/lev/${fname}.stamp")
endforeach()

# makedef
copy_nhdat("${GENERATED_DIR}/dat/bogusmon")
copy_nhdat("${GENERATED_DIR}/dat/data")
copy_nhdat("${GENERATED_DIR}/dat/engrave")
copy_nhdat("${GENERATED_DIR}/dat/epitaph")
copy_nhdat("${GENERATED_DIR}/dat/options")
copy_nhdat("${GENERATED_DIR}/dat/oracles")
copy_nhdat("${GENERATED_DIR}/dat/quest.dat")
copy_nhdat("${GENERATED_DIR}/dat/rumors")

# raw
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/cmdhelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/help")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/hh")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/history")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/keyhelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/license")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/opthelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/wizhelp")

list(TRANSFORM HACKDIR_DATA_FILES PREPEND "${HACKDIR_DATA}/" OUTPUT_VARIABLE HACKDIR_DATA_DEPS)
add_custom_target(
    hackdir_data
    DEPENDS ${HACKDIR_DATA_DEPS} ${STAMPS_LEVELS}
)

if (HACK_DATABASE)
    # Data Librarian
    add_executable(dlb
        "${CMAKE_SOURCE_DIR}/util/dlb_main.c"
        "${CMAKE_SOURCE_DIR}/src/alloc.c"
        "${CMAKE_SOURCE_DIR}/src/dlb.c"
        "${CMAKE_SOURCE_DIR}/util/panic.c"
    )
    target_include_directories(dlb PRIVATE "${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include")
    inject_config(dlb)
    set(GENERATED_ARCHIVE "${HACKDIR}/nhdat")
    add_custom_command(
        OUTPUT "${GENERATED_ARCHIVE}"
        COMMAND dlb c ${HACKDIR_DATA_FILES} *.lev
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${HACKDIR_DATA}/nhdat" "${HACKDIR}/nhdat"
        DEPENDS ${HACKDIR_DATA_DEPS} ${STAMPS_LEVELS}
        WORKING_DIRECTORY "${HACKDIR_DATA}"
    )
    add_custom_target(hackdir_db DEPENDS "${HACKDIR}/nhdat")
endif()

# Data
add_custom_command(
    OUTPUT
    "${CMAKE_BINARY_DIR}/hackdir.stamp"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_SOURCE_DIR}/dat/symbols" "${HACKDIR}/symbols"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_SOURCE_DIR}/dat/sysconf" "${HACKDIR}/sysconf"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${HACKDIR}/save"
    COMMAND "${CMAKE_COMMAND}" -E touch "${HACKDIR}/perm"
    COMMAND "${CMAKE_COMMAND}" -E touch "${HACKDIR}/logfile"
    COMMAND "${CMAKE_COMMAND}" -E touch "${HACKDIR}/xlogfile"
    COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_BINARY_DIR}/hackdir.stamp"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/dat/symbols"
        "${CMAKE_SOURCE_DIR}/dat/sysconf"
)
add_custom_target(
    data
    DEPENDS
    "${CMAKE_BINARY_DIR}/hackdir.stamp"
)

if (HACK_DATABASE)
    add_dependencies(data hackdir_db)
else()
    add_dependencies(data hackdir_data)
endif()

# Hack
file(GLOB_RECURSE SOURCES "src/*.c" "src/*.h" "include/*.h")
list(APPEND SOURCES
    "${GENERATED_DIR}/include/date.h"
    "${GENERATED_DIR}/include/pm.h"
    "${GENERATED_DIR}/include/onames.h"
)

file(GLOB_RECURSE SOURCES_UNIX "sys/unix/*.c")
list(APPEND SOURCES ${SOURCES_UNIX})
list(APPEND SOURCES
    "sys/share/posixregex.c"
    "sys/share/ioctl.c"
    "sys/share/unixtty.c"
)

file(GLOB_RECURSE SOURCES_WIN_TTY "win/tty/*.c")
list(APPEND SOURCES ${SOURCES_WIN_TTY})

if (HACK_WIN_CURSES)
    file(GLOB_RECURSE SOURCES_WIN_CURSES "win/curses/*.c")
    list(APPEND SOURCES ${SOURCES_WIN_CURSES})
endif()

add_executable(${GAME} ${SOURCES})
inject_config(${GAME})
target_include_directories(${GAME} PRIVATE "${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include" ${CURSES_INCLUDE_DIRS})
target_link_libraries(${GAME} ${CURSES_LIBRARIES} ZLIB::ZLIB)
add_dependencies(${GAME} data)

# Install
install(
    TARGETS ${GAME}
    RUNTIME DESTINATION bin
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
        SETGID
)

install(
    DIRECTORY "${HACKDIR}/"
    DESTINATION "${HACK_DIRECTORY}"
    FILE_PERMISSIONS
        OWNER_READ OWNER_WRITE
        GROUP_READ GROUP_WRITE
        WORLD_READ
    DIRECTORY_PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_WRITE GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

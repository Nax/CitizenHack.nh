cmake_minimum_required(VERSION 3.10)
project(CitizenHack)

if (UNIX)
    find_package(Curses REQUIRED)
endif()

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

set(CMAKE_BUILD_RPATH "${CMAKE_BINARY_DIR}/_vendor/lib")
set(CMAKE_NO_SYSTEM_FROM_IMPORTED ON)

set(GAME            "citizenhack")
set(GAMEW           "citizenhackw")
set(GAME_ARCHIVE    "nhdat")

# Dependencies
add_subdirectory(vendor)

# Config
set(HACK_DIRECTORY      "${CMAKE_INSTALL_PREFIX}/lib/citizenhack"   CACHE PATH      "The HACKDIR")
set(HACK_DUMPLOG        ON                                          CACHE BOOL      "Enable the dumplog feature")
set(HACK_DUMPLOG_FILE   "/tmp/citizenhack.%n.%d.log"                CACHE STRING    "The dumplog file template")
set(HACK_DATABASE       ON                                          CACHE BOOL      "Enable the database file")

if (NOT WIN32)
    # WIN32 has two executables
    set(HACK_WIN_CURSES     ON                                          CACHE BOOL      "Enable ncurses graphics")
    if (HACK_WIN_CURSES)
        set(SUGGESTED_HACK_WIN_DEFAULT "curses")
    else()
        set(SUGGESTED_HACK_WIN_DEFAULT "tty")
    endif()
    set(HACK_WIN_DEFAULT     ${SUGGESTED_HACK_WIN_DEFAULT}          CACHE STRING    "The default window system to use")
endif()

set(HACK_DUMPLOG_FILE2 "${HACK_DUMPLOG_FILE}")
if (WIN32)
    string(REPLACE "%" "%%" HACK_DUMPLOG_FILE2 ${HACK_DUMPLOG_FILE2})
endif()

add_compile_definitions(
    DUMPLOG_FILE="${HACK_DUMPLOG_FILE2}"
    SCORE_ON_BOTL
    SECURE
    ZLIB_COMP
)

if (HACK_DATABASE)
    add_compile_definitions(DLB)
endif()

if (HACK_DUMPLOG)
    add_compile_definitions(DUMPLOG)
endif()

if (HACK_WIN_CURSES)
    add_compile_definitions(CURSES_GRAPHICS)
endif()

if (WIN32)
    add_compile_definitions(
        SAFEPROCS
        MSWIN_GRAPHICS
        WIN32CON
    )
else()
    add_compile_definitions(
        HACKDIR="${HACK_DIRECTORY}"
        DEFAULT_WINDOW_SYS="${HACK_WIN_DEFAULT}"
    )
endif()

# Generated files structure
set(GENERATED_DIR           "${CMAKE_BINARY_DIR}/gen")
set(GENERATED_DIR_DUMMY     "${GENERATED_DIR}/dummy")
set(HACKDIR                 "${CMAKE_BINARY_DIR}/hackdir")
if (HACK_DATABASE)
    set(HACKDIR_DATA "${CMAKE_BINARY_DIR}/hackdir_data")
else()
    set(HACKDIR_DATA "${HACKDIR}")
endif()
file(MAKE_DIRECTORY ${HACKDIR} ${HACKDIR_DATA} ${GENERATED_DIR_DUMMY} "${GENERATED_DIR}/include" "${GENERATED_DIR}/src" "${GENERATED_DIR}/dat" "${GENERATED_DIR}/rc")

include_directories("${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include" "${CMAKE_BINARY_DIR}/_vendor/include")

set(RC_FILES  "")
set(RC_FILESW "")
if (WIN32)
    # uudecode
    add_executable(uudecode "${CMAKE_SOURCE_DIR}/sys/share/uudecode.c")
    macro(rc_uudecode _gfx _name _path)
        set(_fullpath "${GENERATED_DIR}/rc/${_name}")
        list(APPEND RC_FILESW "${_fullpath}")
        if (NOT _gfx)
            list(APPEND RC_FILES "${_fullpath}")
        endif()
        add_custom_command(
            OUTPUT "${_fullpath}"
            DEPENDS uudecode "${_path}"
            COMMAND uudecode "${_path}"
            WORKING_DIRECTORY "${GENERATED_DIR}/rc"
            VERBATIM
        )
    endmacro()
    include_directories("${GENERATED_DIR}/rc")

    rc_uudecode(NO  nethack.ico  "${CMAKE_SOURCE_DIR}/sys/windows/nhico.uu")
    rc_uudecode(YES petmark.bmp  "${CMAKE_SOURCE_DIR}/win/win32/petmark.uu")
    rc_uudecode(YES pilemark.bmp "${CMAKE_SOURCE_DIR}/win/win32/pilemark.uu")
    rc_uudecode(YES mnsel.bmp    "${CMAKE_SOURCE_DIR}/win/win32/mnsel.uu")
    rc_uudecode(YES mnselcnt.bmp "${CMAKE_SOURCE_DIR}/win/win32/mnselcnt.uu")
    rc_uudecode(YES mnunsel.bmp  "${CMAKE_SOURCE_DIR}/win/win32/mnunsel.uu")
    rc_uudecode(YES splash.bmp   "${CMAKE_SOURCE_DIR}/win/win32/splash.uu")
    rc_uudecode(YES rip.bmp      "${CMAKE_SOURCE_DIR}/win/win32/rip.uu")

    # tile2bmp
    add_executable(tile2bmp
        "${CMAKE_SOURCE_DIR}/win/share/tile2bmp.c"
        "${CMAKE_SOURCE_DIR}/win/share/tiletext.c"
        "${CMAKE_SOURCE_DIR}/win/share/tilemap.c"
        "${CMAKE_SOURCE_DIR}/src/monst.c"
        "${CMAKE_SOURCE_DIR}/src/objects.c"
        "${CMAKE_SOURCE_DIR}/src/drawing.c"
    )
    target_include_directories(tile2bmp PRIVATE "${CMAKE_SOURCE_DIR}/sys/windows")
    target_compile_definitions(tile2bmp PRIVATE TILETEXT=1)
    list(APPEND RC_FILESW "${GENERATED_DIR}/rc/tiles.bmp")
    add_custom_command(
        OUTPUT "${GENERATED_DIR}/rc/tiles.bmp"
        DEPENDS
            tile2bmp
            "${CMAKE_SOURCE_DIR}/win/share/monsters.txt"
            "${CMAKE_SOURCE_DIR}/win/share/objects.txt"
            "${CMAKE_SOURCE_DIR}/win/share/artifacts.txt"
            "${CMAKE_SOURCE_DIR}/win/share/other.txt"
        COMMAND tile2bmp "${GENERATED_DIR}/rc/tiles.bmp"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/win/share"
        VERBATIM
    )
endif()

# Makedefs
add_executable(
    makedefs
    "${CMAKE_SOURCE_DIR}/src/alloc.c"
    "${CMAKE_SOURCE_DIR}/src/monst.c"
    "${CMAKE_SOURCE_DIR}/src/objects.c"
    "${CMAKE_SOURCE_DIR}/src/date.c"
    "${CMAKE_SOURCE_DIR}/util/panic.c"
    "${CMAKE_SOURCE_DIR}/util/makedefs.c"
)
target_compile_definitions(makedefs PRIVATE FILE_PREFIX=1)
target_link_libraries(makedefs)
add_dependencies(makedefs ep_zlib ep_lua)

function(add_makedef flag)
    cmake_parse_arguments(ADD_MAKEDEF "" "" "OUTPUT;DEPENDS" ${ARGN})
    set(outputs "")
    foreach(o ${ADD_MAKEDEF_OUTPUT})
        list(APPEND outputs "${GENERATED_DIR}/${o}")
    endforeach()
    add_custom_command(
        OUTPUT ${outputs}
        DEPENDS makedefs ${ADD_MAKEDEF_DEPENDS}
        COMMAND makedefs "${GENERATED_DIR_DUMMY}/" "-${flag}"
        VERBATIM
    )
endfunction()

add_makedef(d
    OUTPUT "dat/data"
    DEPENDS "${CMAKE_SOURCE_DIR}/dat/data.base"
)

add_makedef(h
    OUTPUT "dat/oracles"
    DEPENDS "${CMAKE_SOURCE_DIR}/dat/oracles.txt"
)

add_makedef(s
    OUTPUT
        "dat/bogusmon"
        "dat/engrave"
        "dat/epitaph"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/dat/bogusmon.txt"
        "${CMAKE_SOURCE_DIR}/dat/engrave.txt"
        "${CMAKE_SOURCE_DIR}/dat/epitaph.txt"
)

add_makedef(r
    OUTPUT "dat/rumors"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/dat/rumors.fal"
        "${CMAKE_SOURCE_DIR}/dat/rumors.tru"
)

# Tilemap
add_executable(
    tilemap
    "${CMAKE_SOURCE_DIR}/win/share/tilemap.c"
    "${CMAKE_SOURCE_DIR}/src/monst.c"
    "${CMAKE_SOURCE_DIR}/src/objects.c"
    "${CMAKE_SOURCE_DIR}/src/drawing.c"
)
target_include_directories(tilemap PRIVATE "${CMAKE_SOURCE_DIR}/include" "${GENERATED_DIR}/include")
target_link_libraries(tilemap)
add_dependencies(tilemap ep_zlib ep_lua)
add_custom_command(
    OUTPUT
        "${GENERATED_DIR}/src/tile.c"
    COMMAND tilemap
    DEPENDS tilemap
    WORKING_DIRECTORY "${GENERATED_DIR}"
)

# Hackdir data
set(HACKDIR_DATA_FILES "")
macro(copy_nhdat src)
    get_filename_component(_fname ${src} NAME)

    add_custom_command(
        OUTPUT "${HACKDIR_DATA}/${_fname}"
        DEPENDS "${src}"
        COMMAND "${CMAKE_COMMAND}" -E copy "${src}" "${HACKDIR_DATA}/${_fname}"
        VERBATIM
    )
    list(APPEND HACKDIR_DATA_FILES ${_fname})
endmacro()

# Lua Scripts
file(GLOB_RECURSE LUA_SCRIPTS "${CMAKE_SOURCE_DIR}/dat/*.lua")
foreach(s ${LUA_SCRIPTS})
    copy_nhdat("${s}")
endforeach()

# makedef
copy_nhdat("${GENERATED_DIR}/dat/bogusmon")
copy_nhdat("${GENERATED_DIR}/dat/data")
copy_nhdat("${GENERATED_DIR}/dat/engrave")
copy_nhdat("${GENERATED_DIR}/dat/epitaph")
# copy_nhdat("${GENERATED_DIR}/dat/options")
copy_nhdat("${GENERATED_DIR}/dat/oracles")
copy_nhdat("${GENERATED_DIR}/dat/rumors")

# raw
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/cmdhelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/help")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/hh")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/history")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/keyhelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/license")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/opthelp")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/tribute")
copy_nhdat("${CMAKE_SOURCE_DIR}/dat/wizhelp")

list(TRANSFORM HACKDIR_DATA_FILES PREPEND "${HACKDIR_DATA}/" OUTPUT_VARIABLE HACKDIR_DATA_DEPS)
add_custom_target(
    hackdir_data
    DEPENDS ${HACKDIR_DATA_DEPS}
)

if (HACK_DATABASE)
    # Data Librarian
    add_executable(dlb
        "${CMAKE_SOURCE_DIR}/util/dlb_main.c"
        "${CMAKE_SOURCE_DIR}/src/alloc.c"
        "${CMAKE_SOURCE_DIR}/src/dlb.c"
        "${CMAKE_SOURCE_DIR}/util/panic.c"
    )
    target_link_libraries(dlb)
    add_dependencies(dlb ep_zlib ep_lua)
    set(GENERATED_ARCHIVE "${HACKDIR}/nhdat")
    add_custom_command(
        OUTPUT "${GENERATED_ARCHIVE}"
        COMMAND dlb c ${HACKDIR_DATA_FILES}
        COMMAND "${CMAKE_COMMAND}" -E copy "${HACKDIR_DATA}/nhdat" "${HACKDIR}/nhdat"
        DEPENDS ${HACKDIR_DATA_DEPS}
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
file(GLOB_RECURSE SOURCES_UNIX "sys/unix/*.c")
file(GLOB_RECURSE SOURCES_WIN_WIN32 "win/win32/*.c")

set(SOURCES_WINDOWS
    "sys/windows/windmain.c"
    "sys/windows/consoletty.c"
    "sys/windows/windsys.c"
    "sys/windows/win10.c"
    "sys/windows/ntsound.c"
    "${GENERATED_DIR}/src/tile.c"
    "sys/share/cppregex.cpp"
    "win/share/safeproc.c"
)

if (UNIX)
    list(APPEND SOURCES ${SOURCES_UNIX})
    list(APPEND SOURCES
        "sys/share/posixregex.c"
        "sys/share/ioctl.c"
        "sys/share/unixtty.c"
    )
endif()

if (WIN32)
    list(APPEND SOURCES ${SOURCES_WINDOWS} ${SOURCES_WIN_WIN32})
    set(SOURCES_EXTRA_GAME  "${CMAKE_SOURCE_DIR}/win/win32/nethack.rc")
    set(SOURCES_EXTRA_GAMEW "${CMAKE_SOURCE_DIR}/win/win32/NetHackW.rc")
endif()

file(GLOB_RECURSE SOURCES_WIN_TTY "win/tty/*.c")
list(APPEND SOURCES ${SOURCES_WIN_TTY})

if (HACK_WIN_CURSES)
    file(GLOB_RECURSE SOURCES_WIN_CURSES "win/curses/*.c")
    list(APPEND SOURCES ${SOURCES_WIN_CURSES})
endif()

add_executable(${GAME} ${SOURCES} ${SOURCES_EXTRA_GAME} ${RC_FILES})
if (WIN32)
    target_include_directories(${GAME} PRIVATE "sys/windows")
endif()
target_link_libraries(${GAME} ZLIB::ZLIB Lua::Lua ${CURSES_LIBRARIES})
if (WIN32)
    target_link_libraries(${GAME} bcrypt winmm comctl32)
endif()
add_dependencies(${GAME} data)

# Win32 graphical executable
if (WIN32)
    add_executable(${GAMEW} WIN32 ${SOURCES} ${SOURCES_EXTRA_GAMEW} ${RC_FILESW})
    target_include_directories(${GAMEW} PRIVATE "sys/windows")
    target_link_libraries(${GAMEW} ZLIB::ZLIB Lua::Lua)
    target_link_libraries(${GAMEW} bcrypt winmm comctl32)
    add_dependencies(${GAMEW} data)
endif()

# Win32 Key Handlers
if (WIN32)
    add_library(nhraykey SHARED "${CMAKE_SOURCE_DIR}/sys/windows/nhraykey.c")
    add_library(nhdefkey SHARED "${CMAKE_SOURCE_DIR}/sys/windows/nhdefkey.c")
    add_library(nh340key SHARED "${CMAKE_SOURCE_DIR}/sys/windows/nh340key.c")
endif()

# DLLs & files
if (WIN32)
    add_custom_command(
        TARGET ${GAME} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:Lua::Lua>" "$<TARGET_FILE:ZLIB::ZLIB>" "$<TARGET_FILE_DIR:${GAME}>"
        COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/sys/windows/sysconf.template" "$<TARGET_FILE_DIR:${GAME}>"
        COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/sys/windows/.nethackrc.template" "$<TARGET_FILE_DIR:${GAME}>"
        COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/doc/Guidebook.txt" "$<TARGET_FILE_DIR:${GAME}>"
        COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/dat/symbols" "$<TARGET_FILE_DIR:${GAME}>/symbols.template"
        COMMAND "${CMAKE_COMMAND}" -E copy "${CMAKE_SOURCE_DIR}/dat/opthelp" "$<TARGET_FILE_DIR:${GAME}>"
        COMMAND "${CMAKE_COMMAND}" -E copy "${HACKDIR}/nhdat" "$<TARGET_FILE_DIR:${GAME}>"
    )
endif()

# Install
if (WIN32)
    install(
        TARGETS "${GAME}" "${GAMEW}" nhdefkey nhraykey nh340key
        RUNTIME DESTINATION .
    )
    install(
        FILES
            "$<TARGET_FILE:Lua::Lua>"
            "$<TARGET_FILE:ZLIB::ZLIB>"
            "${HACKDIR}/nhdat"
            "${CMAKE_SOURCE_DIR}/dat/opthelp"
            "${CMAKE_SOURCE_DIR}/doc/Guidebook.txt"
            "${CMAKE_SOURCE_DIR}/sys/windows/.nethackrc.template"
            "${CMAKE_SOURCE_DIR}/sys/windows/sysconf.template"
        DESTINATION .
    )
    install(FILES "${CMAKE_SOURCE_DIR}/dat/symbols" DESTINATION . RENAME "symbols.template")
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ".")
    include(InstallRequiredSystemLibraries)
else()
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
endif()

# CPack
execute_process(
    COMMAND git describe --always
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CPACK_PACKAGE_NAME "CitizenHack")
set(CPACK_PACKAGE_VENDOR "Maxime Bacoux")
set(CPACK_PACKAGE_CONTACT "Maxime Bacoux")
set(CPACK_PACKAGE_VERSION "${GIT_VERSION}")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}/pkg")

if (WIN32)
    set(CPACK_GENERATOR "ZIP")
elseif(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_SYSTEM_NAME "mac")
elseif(UNIX)
    set(CPACK_GENERATOR "DEB")
endif()
include(CPack)
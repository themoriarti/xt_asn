cmake_minimum_required(VERSION 3.10)
project(xt_asn VERSION 2.1.0 LANGUAGES C)

# Set default build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Project information
set(PACKAGE_NAME "xtables-addons-asn")
set(PACKAGE_VERSION "${PROJECT_VERSION}")
set(PACKAGE_STRING "${PACKAGE_NAME} ${PACKAGE_VERSION}")

# Build options
option(BUILD_KERNEL_MODULE "Build kernel module" ON)
option(BUILD_USERSPACE "Build userspace library" ON)
option(ENABLE_DEBUG "Enable debug mode" OFF)
option(ENABLE_TESTING "Enable testing" OFF)

# Find required packages
find_package(PkgConfig REQUIRED)

# Find xtables
pkg_check_modules(XTABLES REQUIRED xtables>=1.4.5)

# Find kernel build directory
if(BUILD_KERNEL_MODULE)
    execute_process(
        COMMAND uname -r
        OUTPUT_VARIABLE KERNEL_RELEASE
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    
    set(KERNEL_BUILD_DIR "/lib/modules/${KERNEL_RELEASE}/build" 
        CACHE PATH "Kernel build directory")
    
    if(NOT EXISTS "${KERNEL_BUILD_DIR}")
        message(WARNING "Kernel build directory not found: ${KERNEL_BUILD_DIR}")
        set(BUILD_KERNEL_MODULE OFF)
    endif()
endif()

# Compiler flags
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Wstrict-prototypes")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_LARGEFILE_SOURCE=1 -D_LARGE_FILES -D_FILE_OFFSET_BITS=64 -D_REENTRANT")

if(ENABLE_DEBUG)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -DDEBUG")
else()
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O2 -DNDEBUG")
endif()

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/extensions
    ${XTABLES_INCLUDE_DIRS}
)

# Definitions
add_definitions(${XTABLES_CFLAGS})

# Get xtables library directory
execute_process(
    COMMAND pkg-config --variable=xtlibdir xtables
    OUTPUT_VARIABLE XTABLES_LIBDIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

if(NOT XTABLES_LIBDIR)
    set(XTABLES_LIBDIR "${CMAKE_INSTALL_PREFIX}/lib/xtables")
endif()

message(STATUS "Xtables library directory: ${XTABLES_LIBDIR}")

# Userspace library
if(BUILD_USERSPACE)
    add_library(xt_asn SHARED extensions/libxt_asn.c)
    target_link_libraries(xt_asn ${XTABLES_LIBRARIES})
    
    # Install userspace library
    install(TARGETS xt_asn
        LIBRARY DESTINATION ${XTABLES_LIBDIR}
    )
    
    # Install man page
    install(FILES extensions/libxt_asn.man
        DESTINATION ${CMAKE_INSTALL_PREFIX}/share/man/man8
        RENAME libxt_asn.8
    )
endif()

# Kernel module
if(BUILD_KERNEL_MODULE)
    # Create Makefile for kernel build
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/Kbuild.in
        ${CMAKE_CURRENT_BINARY_DIR}/Kbuild
        @ONLY
    )
    
    # Copy source files to build directory
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/extensions/xt_asn.c
        ${CMAKE_CURRENT_BINARY_DIR}/xt_asn.c
        COPYONLY
    )
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/extensions/xt_asn.h
        ${CMAKE_CURRENT_BINARY_DIR}/xt_asn.h
        COPYONLY
    )
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/extensions/compat_xtables.h
        ${CMAKE_CURRENT_BINARY_DIR}/compat_xtables.h
        COPYONLY
    )
    
    # Build kernel module
    add_custom_target(kernel_module ALL
        COMMAND ${CMAKE_MAKE_PROGRAM} -C ${KERNEL_BUILD_DIR} M=${CMAKE_CURRENT_BINARY_DIR} modules
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Building kernel module"
    )
    
    # Install kernel module
    install(CODE "
        execute_process(
            COMMAND ${CMAKE_MAKE_PROGRAM} -C ${KERNEL_BUILD_DIR} M=${CMAKE_CURRENT_BINARY_DIR} modules_install
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
        execute_process(COMMAND depmod -a)
    ")
endif()

# ASN database tools
install(PROGRAMS 
    asn/update-asndata.sh
    asn/download-asndata.sh
    asn/xt_asn_build
    DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)

install(FILES
    asn/bgp_table_to_text.pl
    DESTINATION ${CMAKE_INSTALL_PREFIX}/share/xt_asn
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)

# Database directory
install(DIRECTORY DESTINATION ${CMAKE_INSTALL_PREFIX}/share/xt_asn/BE)
install(DIRECTORY DESTINATION ${CMAKE_INSTALL_PREFIX}/share/xt_asn/LE)

# Documentation
install(FILES
    README.md
    INSTALL.md
    LICENSE
    DESTINATION ${CMAKE_INSTALL_PREFIX}/share/doc/xt_asn
)

# Configuration
if(ENABLE_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

# Uninstall target
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    @ONLY
)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake
)

# Package configuration
set(CPACK_PACKAGE_NAME ${PACKAGE_NAME})
set(CPACK_PACKAGE_VERSION ${PACKAGE_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "IPTables ASN filtering module")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
set(CPACK_PACKAGE_CONTACT "maintainer@example.com")
set(CPACK_PACKAGE_VENDOR "xt_asn project")

# DEB package configuration
set(CPACK_DEBIAN_PACKAGE_DEPENDS "iptables (>= 1.4.5), bgpdump, libtext-csv-xs-perl")
set(CPACK_DEBIAN_PACKAGE_SECTION "net")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")

# RPM package configuration  
set(CPACK_RPM_PACKAGE_GROUP "System Environment/Kernel")
set(CPACK_RPM_PACKAGE_LICENSE "GPL")
set(CPACK_RPM_PACKAGE_REQUIRES "iptables >= 1.4.5, bgpdump, perl-Text-CSV_XS")

include(CPack)

# Status message
message(STATUS "")
message(STATUS "Configuration summary:")
message(STATUS "  Package: ${PACKAGE_STRING}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Build kernel module: ${BUILD_KERNEL_MODULE}")
message(STATUS "  Build userspace: ${BUILD_USERSPACE}")
message(STATUS "  Debug mode: ${ENABLE_DEBUG}")
message(STATUS "  Testing: ${ENABLE_TESTING}")
if(BUILD_KERNEL_MODULE)
    message(STATUS "  Kernel build dir: ${KERNEL_BUILD_DIR}")
endif()
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  Xtables library dir: ${XTABLES_LIBDIR}")
message(STATUS "")

# Tests for xt_asn
find_program(BASH_PROGRAM bash)

if(BASH_PROGRAM)
    # Unit tests for userspace library
    add_test(NAME userspace_lib_test
        COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/test_userspace.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    
    # Integration tests
    add_test(NAME integration_test
        COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/test_integration.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    
    # ASN data processing tests
    add_test(NAME asn_data_test
        COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/test_asn_data.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    
    # Performance tests
    add_test(NAME performance_test
        COMMAND ${BASH_PROGRAM} ${CMAKE_CURRENT_SOURCE_DIR}/test_performance.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
    
    set_tests_properties(userspace_lib_test integration_test asn_data_test performance_test
        PROPERTIES TIMEOUT 300
    )
else()
    message(WARNING "bash not found - tests will not be available")
endif()

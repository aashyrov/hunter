# Copyright (c) 2015-2017, Ruslan Baratov
# All rights reserved.

include(hunter_internal_error)
include(hunter_lock_directory)
include(hunter_make_directory)
include(hunter_print_cmd)
include(hunter_status_debug)
include(hunter_status_print)
include(hunter_assert_not_empty_string)

function(hunter_calculate_toolchain_sha1 hunter_self hunter_base)
  hunter_assert_not_empty_string("${hunter_self}")
  hunter_assert_not_empty_string("${hunter_base}")
  hunter_assert_not_empty_string("${CMAKE_BINARY_DIR}")
  hunter_assert_not_empty_string("${CMAKE_GENERATOR}")

  if(CMAKE_TOOLCHAIN_FILE)
    set(use_toolchain "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
  else()
    set(use_toolchain "")
  endif()

  hunter_status_print("Calculating Toolchain-SHA1")

  set(temp_project_dir "${CMAKE_BINARY_DIR}/_3rdParty/Hunter/toolchain")
  set(create_script "${hunter_self}/scripts/create-toolchain-info.cmake")

  set(toolchain_info_nolf "${temp_project_dir}/toolchain.info.NOLF")
  set(toolchain_info_local "${temp_project_dir}/toolchain.info")

  file(REMOVE_RECURSE "${toolchain_info_nolf}")

  if(HUNTER_BINARY_DIR)
    hunter_lock_directory("${HUNTER_BINARY_DIR}" "")
    set(temp_build_dir "${HUNTER_BINARY_DIR}/toolchain")
  else()
    set(temp_build_dir "${temp_project_dir}/_builds")
  endif()

  file(REMOVE_RECURSE "${temp_build_dir}")

  if(HUNTER_STATUS_DEBUG)
    set(logging_params "")
  else()
    set(logging_params "OUTPUT_QUIET")
  endif()

  # create all directories
  file(WRITE "${temp_project_dir}/CMakeLists.txt" "###")

  configure_file(
       "${create_script}"
       "${temp_project_dir}/CMakeLists.txt"
       COPYONLY
  )

  set(
      cmd
      "${CMAKE_COMMAND}"
      "-DTOOLCHAIN_INFO_FILE=${toolchain_info_nolf}"
      "${use_toolchain}"
      "-DHUNTER_SELF=${hunter_self}"
      "-G${CMAKE_GENERATOR}"
      "-H${temp_project_dir}"
      "-B${temp_build_dir}"
      "-DANDROID_ABI=x86_64"
  )

  string(COMPARE NOTEQUAL "${CMAKE_MAKE_PROGRAM}" "" has_make)
  if(has_make)
    list(APPEND cmd "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}")
  endif()

  string(COMPARE NOTEQUAL "${CMAKE_GENERATOR_TOOLSET}" "" has_toolset)
  if(has_toolset)
    list(APPEND cmd "-T" "${CMAKE_GENERATOR_TOOLSET}")
  endif()

  string(COMPARE NOTEQUAL "${CMAKE_GENERATOR_PLATFORM}" "" has_gen_platform)
  if(has_gen_platform)
    list(APPEND cmd "-A" "${CMAKE_GENERATOR_PLATFORM}")
  endif()

  foreach(configuration ${HUNTER_CONFIGURATION_TYPES})
    string(TOUPPER "${configuration}" configuration_upper)
    list(
        APPEND
        cmd
        "-DCMAKE_${configuration_upper}_POSTFIX=${CMAKE_${configuration_upper}_POSTFIX}"
    )
  endforeach()

  string(COMPARE EQUAL "${HUNTER_BUILD_SHARED_LIBS}" "" is_empty)
  if(NOT is_empty)
    list(APPEND cmd "-DHUNTER_BUILD_SHARED_LIBS=${HUNTER_BUILD_SHARED_LIBS}")
  endif()

  hunter_print_cmd("${temp_project_dir}" "${cmd}")

  # HUNTER_CONFIGURATION_TYPES notes: list is tricky...
  execute_process(
      COMMAND
          ${cmd}
          "-DHUNTER_CONFIGURATION_TYPES=${HUNTER_CONFIGURATION_TYPES}"
      WORKING_DIRECTORY "${temp_project_dir}"
      RESULT_VARIABLE generate_result
      ${logging_params}
  )
  if(NOT generate_result EQUAL "0")
    hunter_internal_error(
        "Generate failed: exit with code ${generate_result}"
    )
  endif()

  # About '@ONLY': no substitutions expected but COPYONLY can't be
  # used with NEWLINE_STYLE
  configure_file(
      "${toolchain_info_nolf}"
      "${toolchain_info_local}"
      @ONLY
      NEWLINE_STYLE LF
  )

  file(SHA1 "${toolchain_info_local}" HUNTER_GATE_TOOLCHAIN_SHA1)
  set(HUNTER_GATE_TOOLCHAIN_SHA1 "${HUNTER_GATE_TOOLCHAIN_SHA1}" PARENT_SCOPE)

  hunter_make_directory("${hunter_base}" "${HUNTER_GATE_SHA1}" hunter_id_path)

  hunter_make_directory(
      "${hunter_id_path}"
      "${HUNTER_GATE_TOOLCHAIN_SHA1}"
      hunter_toolchain_id_path
  )

  set(toolchain_info_global "${hunter_toolchain_id_path}/toolchain.info")
  if(EXISTS "${toolchain_info_global}")
    hunter_status_debug("Already exists: ${toolchain_info_global}")
    return()
  endif()

  hunter_lock_directory("${hunter_toolchain_id_path}" "")
  if(EXISTS "${toolchain_info_global}")
    hunter_status_debug("Already exists: ${toolchain_info_global}")
    return()
  endif()

  set(
      toolchain_info_torename
      "${hunter_toolchain_id_path}/toolchain.info.TORENAME"
  )
  configure_file(
      "${toolchain_info_local}"
      "${toolchain_info_torename}"
      COPYONLY
  )

  file(RENAME "${toolchain_info_torename}" "${toolchain_info_global}")

  hunter_status_debug("Toolchain info: ${toolchain_info_global}")
  hunter_status_debug("Toolchain SHA1: ${HUNTER_GATE_TOOLCHAIN_SHA1}")

  file(REMOVE_RECURSE "${temp_build_dir}")
endfunction()

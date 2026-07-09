cmake_minimum_required(VERSION 3.0)

find_path(QUESTASIM_PATH
  NAMES vsim
  PATHS ${QUESTASIM_ROOT_DIR} ENV PATH
  PATH_SUFFIXES bin
)

if(NOT EXISTS ${QUESTASIM_PATH})

  message(WARNING "QUESTASIM not found.")

else()

  get_filename_component(QUESTASIM_ROOT_DIR ${QUESTASIM_PATH} DIRECTORY)

  set(QUESTASIM_FOUND TRUE)
  set(QUESTASIM_BINARY ${QUESTASIM_ROOT_DIR}/bin/vsim)

  message(STATUS "Found QUESTASIM at ${QUESTASIM_ROOT_DIR}.")

endif()
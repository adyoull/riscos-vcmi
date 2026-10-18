# crossdev's toolchain file, plus work/stage (the libraries build-deps.sh
# makes) as a third root for find_package, find_library and find_path.
# CROSSDEV and STAGE come from build/env.sh on the first run; later runs
# (CMake re-running itself from ninja) use the cached values.
if(DEFINED ENV{CROSSDEV})
  set(RISCOS_VCMI_CROSSDEV "$ENV{CROSSDEV}" CACHE PATH "riscos-crossdev checkout")
  set(RISCOS_VCMI_STAGE "$ENV{STAGE}" CACHE PATH "libraries built by build-deps.sh")
endif()
set(CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RISCOS_VCMI_CROSSDEV RISCOS_VCMI_STAGE)
include("${RISCOS_VCMI_CROSSDEV}/cmake/riscos.cmake")
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES RISCOS_VCMI_CROSSDEV RISCOS_VCMI_STAGE)
list(APPEND CMAKE_FIND_ROOT_PATH "${RISCOS_VCMI_STAGE}")

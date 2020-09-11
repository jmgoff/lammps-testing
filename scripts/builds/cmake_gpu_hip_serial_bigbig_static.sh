#!/bin/bash -x
if [ -z "${LAMMPS_DIR}" ]
then
    echo "Must set LAMMPS_DIR environment variable"
    exit 1
fi

if [ -z "${LAMMPS_CI_RUNNER}" ]
then
    # local testing
    BUILD=build-$(basename $0 .sh)
else
    # when running lammps_test or inside jenkins
    BUILD=build
fi

exists()
{
  command -v "$1" >/dev/null 2>&1
}

if exists "cmake3"
then
    CMAKE_COMMAND=cmake3
else
    CMAKE_COMMAND=cmake
fi

LAMMPS_COMPILE_NPROC=${LAMMPS_COMPILE_NPROC-8}

if [ -z "${CCACHE_DIR}" ]
then
    export CCACHE_DIR="$PWD/.ccache"
fi

export PYTHON=$(which python3)

# Set up environment
ccache -M 10G
virtualenv --python=$PYTHON pyenv
source pyenv/bin/activate
pip install --upgrade pip setuptools

# Create build directory
if [ -d "${BUILD}" ]; then
    rm -rf ${BUILD}
fi

mkdir -p ${BUILD}
cd ${BUILD}

# needed for linker during build to find libcuda.so.1
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${LIBRARY_PATH}

export HIP_PLATFORM=hcc
export HCC_AMDGPU_TARGET=gfx906

# Configure
#      -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
#      -D CMAKE_CUDA_COMPILER_LAUNCHER=ccache \
${CMAKE_COMMAND} -C ${LAMMPS_DIR}/cmake/presets/most.cmake \
      -D CMAKE_TUNE_FLAGS="-Wall -Wextra -Wno-unused-result -Wno-macro-redefined" \
      -D CMAKE_INSTALL_PREFIX=${VIRTUAL_ENV} \
      -D CMAKE_LIBRARY_PATH=$LIBRARY_PATH \
      -D BUILD_MPI=off \
      -D BUILD_OMP=off \
      -D BUILD_SHARED_LIBS=off \
      -D LAMMPS_SIZES=BIGBIG \
      -D LAMMPS_EXCEPTIONS=off \
      -D PKG_USER-INTEL=on \
      -D PKG_MPIIO=off \
      -D PKG_USER-AWPMD=on \
      -D PKG_USER-BOCS=on \
      -D PKG_USER-EFF=on \
      -D PKG_USER-H5MD=on \
      -D PKG_USER-MANIFOLD=on \
      -D PKG_USER-MOLFILE=on \
      -D PKG_USER-NETCDF=on \
      -D PKG_USER-PTM=on \
      -D PKG_USER-QTB=on \
      -D PKG_USER-SDPD=on \
      -D PKG_USER-SMTBQ=on \
      -D PKG_USER-TALLY=on \
      -D PKG_GPU=on \
      -D GPU_API=HIP \
      -D HIP_ARCH=gfx906 \
      -D CMAKE_CXX_COMPILER=hipcc \
      -D CMAKE_VERBOSE_MAKEFILE=on \
      ${LAMMPS_DIR}/cmake || exit 1

# Build
cmake --build . -- -j ${LAMMPS_COMPILE_NPROC} || exit 1

# Install
# running install target repeats the compilation with Kokkos enabled
# cmake --build . --target  install || exit 1
deactivate

ccache -s
#!/bin/bash
export WORKING_DIR=$PWD
SCRIPTDIR="$(dirname "$(realpath "$0")")"

# copy tests
rsync -a --delete $LAMMPS_TESTING_DIR/tests .

source pyenv/bin/activate

# install lammps-testing package
cd $LAMMPS_TESTING_DIR
python setup.py install
cd $WORKING_DIR



# run tests
export LD_LIBRARY_PATH=$VIRTUAL_ENV/lib64:$VIRTUAL_ENV/lib:$LD_LIBRARY_PATH
export LAMMPS_BINARY=${VIRTUAL_ENV}/bin/lmp
export LAMMPS_POTENTIALS="${VIRTUAL_ENV}/share/lammps/potentials"
export LAMMPS_MPI_MODE="openmpi"
export LAMMPS_TEST_MODES="serial"
export LAMMPS_TESTING_NPROC=8

lammps_run_tests --processes ${LAMMPS_TESTING_NPROC} tests/test_commands.py tests/test_examples.py

make -C build gen_coverage_xml

deactivate
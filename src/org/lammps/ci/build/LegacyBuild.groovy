package org.lammps.ci.build

enum LAMMPS_MODE {
    exe,
    shexe,
    shlib
}

enum LAMMPS_SIZES {
    SMALLSMALL,
    SMALLBIG,
    BIGBIG
}

abstract class LegacyBuild implements Serializable {
    protected def name
    protected def steps
    def lammps_mode  = LAMMPS_MODE.exe
    def lammps_mach  = 'serial'
    def lammps_size = LAMMPS_SIZES.SMALLBIG

    LegacyBuild(name, steps) {
        this.name  = name
        this.steps = steps
    }

    protected def enable_packages() {
        steps.stage('Enable packages') {
            steps.sh '''
            make -C lammps/src purge
            make -C lammps/src clean-all
            make -C lammps/src yes-all
            make -C lammps/src no-lib
            make -C lammps/src no-mpiio
            make -C lammps/src no-user-omp
            make -C lammps/src no-user-intel
            make -C lammps/src no-user-lb
            make -C lammps/src no-user-smd
            make -C lammps/src yes-user-molfile yes-compress yes-python
            make -C lammps/src yes-poems yes-user-colvars yes-user-awpmd yes-user-meamc
            make -C lammps/src yes-user-h5md
            make -C lammps/src yes-user-dpd
            make -C lammps/src yes-user-reaxc
            make -C lammps/src yes-user-meamc
            '''
        }
    }

    protected def build_libraries() {
        steps.stage('Building libraries') {
            steps.sh '''
            make -C lammps/lib/colvars -f Makefile.g++ clean
            make -C lammps/lib/poems -f Makefile.g++ CXX="${COMP}" clean
            make -C lammps/lib/awpmd -f Makefile.mpicc CC="${COMP}" clean
            make -C lammps/lib/h5md -f Makefile.h5cc clean
            make -C lammps/src/STUBS clean

            make -j 8 -C lammps/lib/colvars -f Makefile.g++ CXX="${COMP}"
            make -j 8 -C lammps/lib/poems -f Makefile.g++ CXX="${COMP}"
            make -j 8 -C lammps/lib/awpmd -f Makefile.mpicc CC="${COMP}"
            make -j 8 -C lammps/lib/h5md -f Makefile.h5cc
            '''
        }
    }

    protected def configure() {
        steps.env.CCACHE_DIR = steps.pwd() + '/.ccache'
        steps.env.COMP     = 'g++'
        steps.env.MACH     = "${lammps_mach}"
        steps.env.MODE     = "${lammps_mode}"
        steps.env.LMPFLAGS = '-sf off'
        steps.env.LMP_INC  = "-I../../src/STUBS -I/usr/include/hdf5/serial -DLAMMPS_${lammps_size} -DFFT_KISSFFT -DLAMMPS_GZIP -DLAMMPS_PNG -DLAMMPS_JPEG -Wall -Wextra -Wno-unused-result -Wno-unused-parameter -Wno-maybe-uninitialized"
        steps.env.JPG_LIB  = '-L../../src/STUBS/ -L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -lmpi_stubs -ljpeg -lpng -lz'

        steps.env.CC = 'gcc'
        steps.env.CXX = 'g++'
        steps.env.OMPI_CC = 'gcc'
        steps.env.OMPI_CXX = 'g++'
    }

    def build() {
        configure()

        steps.sh 'ccache -C'
        steps.sh 'ccache -M 5G'

        enable_packages()
        build_libraries()

        steps.stage('Compiling') {
            steps.sh 'make -j 8 -C lammps/src mode=${MODE} ${MACH} MACH=${MACH} CC="${COMP}" LINK="${COMP}" LMP_INC="${LMP_INC}" JPG_LIB="${JPG_LIB}" LMPFLAGS="${LMPFLAGS}"'
        }

        steps.sh 'ccache -s'
    }
}
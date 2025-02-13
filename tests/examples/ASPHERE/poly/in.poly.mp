# SRD viscosity demo - poydisperse spheres

units		lj
atom_style	sphere
atom_modify	first big
dimension	2

# create big particles with 3 different types and diameters

lattice		sq 0.3
region		box block 0 10 0 10 -0.5 0.5
create_box	4 box
create_atoms	1 region box

group		big type 1
set		group big type/fraction 2 0.33 394895
set		group big type/fraction 3 0.5 989894
group		big type 2 3

set		type 1*3 mass 1.0
velocity	big create 1.44 87287 loop geom

# equilibrate big particles, repulsive only to prevent aggregation

pair_style	lj/cut 1.12
pair_coeff	1 1 1.0 1.0 1.12
pair_coeff	2 2 1.0 2.0 2.24
pair_coeff	3 3 1.0 1.5 1.68
pair_coeff	4 4 0.0 1.0 0.0

neighbor	0.3 bin
neigh_modify	delay 0 every 1 check yes

fix		1 big nve
fix		2 all enforce2d

#dump		1 all atom 10 dump.poly.equil

run		1000

#undump		1
unfix		1
unfix		2

# add small particles as hi density lattice

region		plane block INF INF INF INF -0.001 0.001 units box
lattice		sq 250.0
create_atoms	4 region plane

set		type 4 mass 0.1
group		small type 4
velocity	small create 1.0 593849 loop geom

# delete overlaps
# must set *-4 cutoffs to non-zero values

pair_style	lj/cut 2.5
pair_coeff	1 1 1.0 1.0
pair_coeff	2 2 1.0 2.0
pair_coeff	3 3 1.0 1.5
pair_coeff	1 4 0.0 1.0 0.5
pair_coeff	2 4 0.0 1.0 1.0
pair_coeff	3 4 0.0 1.0 0.75
pair_coeff	4 4 0.0 1.0 0.0

delete_atoms	overlap 1.0 small big

# SRD run

reset_timestep	0

neighbor	0.3 bin
neigh_modify	delay 0 every 1 check yes

comm_modify	mode multi group big vel yes
neigh_modify	include big

# no pairwise interactions with small particles

pair_style	lj/cut 1.12
pair_coeff	1 1 1.0 1.0 1.12
pair_coeff	2 2 1.0 2.0 2.24
pair_coeff	3 3 1.0 1.5 1.68
pair_coeff	4 4 0.0 1.0 0.0

# use fix SRD to push small particles out from inside big ones
# if comment out, big particles won't see SRD particles

timestep	0.001

fix		1 big nve
fix	        2 small srd 20 big 1.0 0.25 49894 shift yes 54979 &
		  search 0.2 inside ignore
fix		3 small viscosity 10 x y 50
fix		4 all enforce2d

# diagnostics

compute		tbig big temp/sphere
variable	pebig equal pe*atoms/count(big)
variable	ebig equal etotal*atoms/count(big)
thermo_style	custom step temp f_2[8] etotal v_pebig v_ebig press &
		f_2[1] f_2[2] f_2[3] f_2[4] f_2[5] &
		f_2[6] f_2[7] f_2[8] f_2[9] f_2[10] f_2[11]

thermo_modify	temp tbig
thermo		1000

#dump		1 all atom 500 dump.poly.mp

#dump		1 all image 500 image.*.jpg type type zoom 1.6
#dump_modify	1 pad 6 adiam 1 1 adiam 2 2.0 adiam 3 1.5 adiam 4 0.1

run		10000

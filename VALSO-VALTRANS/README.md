# VALSO-VALTRANS

## Table of Contents
1. [Introduction](#introduction)
2. [Getting Started](#getting_started)
3. [How to run](#howtorun)
4. [File Structure](#files)
5. [Output](#output)
6. [Authors](#authors)
7. [Licence](#licence)
8. [Acknowledgements](#acknowledgement)

<a name="introduction"></a>
## Introduction

A software package for ocean scientists to calculate and plot the following evaluation metrics to compare North Atlantic ocean biases between CMIP models
  with a NEMO ocean:

   * VALSO metrics (Southern Ocean assessment):
     * Drake Passage net eastward transport (ACC)
     * Weddell gyre strength
     * Ross gyre strength
     * Salinity of HSSW in west Weddell and west Ross Seas
     * Intrusion of CDW in Amundsen sea
     * Intrusion of CDW on East Ross shelf

   * VALTRANS metrics (Straits transports and exchanges):
     * North Atlantic deep overflows: Denmark Strait and Faroe Bank Channel.
     * Marginal Seas exchanges: Gibraltar, Bab el Mandeb, Strait of Hormuz.
     * Indonesian Throughflow: Lombok Strait, Ombai Strait, Timor Passage.

Note that there is also a set of metrics called VALGLO but this needs debugging.

Currently works for output from eORCA1, eORCA025 and eORCA12 models. 

<a name="getting_started"></a>
## Installation and running

Clone the MARINE_VAL repository:

```
git clone https://github.com/JMMP-Group/MARINE_VAL
```

Build the CDFTOOLS executables. Note the make macro and modules shown 
below work for the current Met Office linux servers

```
module load gcc/8.1.0 mpi/mpich/3.2.1/gnu/8.1.0 \
            hdf5/1.8.20/gnu/8.1.0               \
            netcdf/4.6.1/gnu/8.1.0
cd MARINE_VAL/CDFTOOLS-4.0/src
ln -s ../Macrolib/macro.gfortran_metoffice make.macro
make
```
Edit environment variables in `param.bash` to fit your setup/need.
   * mesh mask location with mesh mask name
   * location of the CDFTOOLS toolbox
   * where to store the data output (or link to existing data location) 

Edit `param.bash` to define which metrics you want to calculate, 
normally a package like VALSO or VALTRANS, but you can pick and choose
individual metrics.

Edit `style.db` to define labels, colours and line styles for the 
integrations you want to plot (some examples provided). 

Process the data to generate the timeseries data:   

`./run_all.bash [CONFIG] [YEARB] [YEARE] [FREQ] [RUNID list]`, for example : 

```
./run_all.bash eORCA025 1976 1977 1y u-ar685 u-bj000 u-bn477 u-az867 u-am916 u-ba470
```
`[CONFIG]` options currently eORCA1, eORCA025 or eORCA12.
`[FREQ]` options currently 1y for annual means or 1m for monthly means.


Output from the processing scripts appears under the SLURM directory. 

Build the plot for the Southern Ocean:
* `./run_plot_VALSO.bash [KEY] [FREQ] [RUNID list]`, for example : 
```
./run_plot_VALSO.bash cpl_and_forced 1y u-am916 u-az867 u-ba470 u-ar685 u-bj000 u-bn477
```
`[KEY]` is an arbitrary label that will be used to name the output PNG file.

## Output

![Alt text](FIGURES/example.png?raw=true "Example of the VALSO output")


* figure [KEY].png

Other output : 
* bsf, bottom T, bottom S, september mld netcdf file for each year in your DATPATH directory.
* all individual time series are saved in FIGURES along with the txt file describing the exact command line done to build it


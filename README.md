# MARINE_VAL

## Table of Contents
1. [Introduction](#introduction)
2. [Installation and running](#installation_and_running)
3. [Output](#output)
4. [Observations](#observations)
5. [Authors](#authors)
6. [Licence](#licence)
7. [Acknowledgements](#acknowledgement)

<a name="introduction"></a>
## Introduction

A software package for ocean scientists to calculate and plot scalar evaluation metrics from ocean general circualtion models (OGCM) 
based on [Nucleus for European Modelling of the Ocean](https://www.nemo-ocean.eu/) (NEMO). 
The data processing is currently mostly based on the [CDFTools](https://github.com/meom-group/CDFTOOLS) package. 
The evaluation metrics are grouped into three packages although any combination of metrics can be calculated and plotted:

   * **VALSO** metrics (Southern Ocean assessment):
     * Drake Passage net eastward transport (ACC)
     * Weddell gyre strength
     * Ross gyre strength
     * Salinity of High Salinity Shelf Water (HSSW) in west Weddell and west Ross Seas
     * Intrusion of Circumpolar Deep Water (CDW) in Amundsen sea
     * Intrusion of CDW on East Ross shelf
     * Census of Antarctic Bottom Water (AABW)

   * **VALNA** metrics (North Atlantic assessment):
     * Subpolar gyre strength (Sv)
     * Subpolar gyre heat content (J)
     * Subpolar gyre salt content
     * AMOC at 26.5N at max. depth (Sv)
     * Zonally averaged AMOC in depth and sigma-2000 space (Sv)
     * OHT at 26.5N (PW)
     * Mixed layer depth in Labrador Sea in March (m)
     * Census of the magnitude and depth of the maximum salinity in the Mediterranean overflow area
     * Mean SSS anomaly in Labrador Sea (PSU)
     * Mean SST anomaly off Newfoundland (degC)
     * GS separation latitude (degN)
     * NA current latitude (degN)
     * Overturning streamfucntion profiles for the eastern and western legs of the OSNAP array in sigma-theta space.

   * **VALTRANS** metrics (Straits transports and exchanges):
     * North Atlantic deep overflows: Denmark Strait and Faroe Bank Channel.
     * Marginal Seas exchanges: Gibraltar, Bab el Mandeb, Strait of Hormuz.
     * Indonesian Throughflow: Lombok Strait, Ombai Strait, Timor Passage.

<a name="installation_and_running"></a>
## Installation and running

### Installation

1) Clone the MARINE_VAL repository:

```
git clone https://github.com/JMMP-Group/MARINE_VAL
```

2) Clone CDFFFTOOLS repository:

```
git clone --recurse-submodules https://github.com/JMMP-Group/CDFTOOLS.git CDFTOOLS_jmmp

N.B.: we shuld add the meom-group repo once our modifications are merged. 
```

Build the CDFTOOLS executables -> see instructions [here](https://github.com/JMMP-Group/CDFTOOLS?tab=readme-ov-file#compiling-cdftools).

3) Create the needed conda environment

```
cd MARINE_VAL
conda env create -f marval.yml
```

4) Install the nordic-seas validation package

```
cd ../
git clone git@github.com:JMMP-Group/nordic-seas-validation.git
cd nordic-seas-validation.git
conda activate marval
pip install -e .
python -c "import nsv"
cd ../MARINE_VAL
```

### Data processing

Edit environment variables in `param.bash` to fit your setup/need, including:
   * $MARINE_VAL: path of local installation of MARINE_VAL toolbox
   * $MSKPATH: directory where model mesh_mask (and bathymetry) files are stored.
   * $CDFPATH: location of the CDFTOOLS toolbox
   * $NMLPATH: path of the namelist to control names of dimensions and variables
               in files to be analysed
   * $DATPATH: where to store the data output (or link to existing data location) 

Edit `param.bash` to define which metrics you want to calculate, 
normally a package like VALSO, VALNA or VALTRANS, but you can pick and choose
individual metrics.

Process the data to generate the timeseries data:   

```
./run_proc.bash -C [chunksize] -B [BATHY] -V [ZCOMSHMSK] [MESHMASK] [YEARB] [YEARE] [FREQ] [RUNID list]
```
where, the optional parameters are:

 * `[chunksize]`: is the number of dates that should be restored from MASS at a time, recommended value at least 10 or 20 to avoid clogging MASS with lots of small retrievals.

 * `[BATHY]`: is the name of the bathymetry file that is stored in the $MSKPATH directory. Note that the bathymetry file is only required for metrics involving transports through straits or the OSNAP MOC. If needed, it can be created from the mesh_mask file using `SCRIPT/bathy_from_dommesh.py`.

 * `[ZCOMSHMSK]: the z-levels mesh_mask.nc where you want to vertically remap your data - this is only needed if your model us using generalised vertical coordinates (e.g. sigma-coordinates, multi-envelope s-cooridnates).

while the mandatory arguments are

 * `[MESHMASK]` is the name of the mesh_mask file found in $MSKPATH.
 * `[FREQ]` options currently 1y for annual means or 1m for monthly means.
 * `[YEARB]` start year of the analysis
 * `[YEARE]` end year of the analysis
 * `[RUNID list]` list of the simualtions IDs to be retrieved and analysed
 
for example : 
```
./run_all.bash -C 20 -B bathymetry_eORCA025-GO6.nc mesh_mask_eORCA025-GO6.nc 1981 1990 1y u-cl681
```
Output from the processing scripts appears under the JOBOUT/RUNID directory.

Note: each time the tool is run, it is possible to only analyse simulations that are using the same model geometry - i.e., bathymetry, mesh_mask.nc, etc ...

### Plotting timeseries

Edit `style.db` to define labels, colours and line styles for the 
integrations you want to plot (some examples provided). 

Plotting scripts are provided to produce sets of plots for each of the three packages, VALSO, VALNA and VALTRANS (mainly timeseries but not exclusively). For example, to generate a standard set of VALSO plots, type:
```
./run_plot_VALSO.bash [KEY] [FREQ] [RUNID list]
``` 
for example : 
```
./run_plot_VALSO.bash cpl_and_forced 1y u-am916 u-az867 u-ba470 u-ar685 u-bj000 u-bn477
```
 * `[KEY]` is an arbitrary label that will be used to name the output PNG file.

The individual timeseries plots will appear in the FIGURES directory and the combined figure in the main MARINE_VAL directory.

<a name="output"></a>
## Example Output

VALSO output:

![Alt text](FIGURES/example_VALSO.png?raw=true "Example of the VALSO output")

VALNA output:

![Alt text](FIGURES/example_VALNA.png?raw=true "Example of the VALSO output")

VALTRANS output:

![Alt text](FIGURES/example_VALTRANS.png?raw=true "Example of the VALSO output")

Other output : 
* bsf, september mld netcdf file for each year in your DATPATH directory.
* all individual time series are saved in FIGURES along with the txt file describing the exact command line done to build it

<a name="observations"></a>
## Observations
This section gives a bit more detail on where the observations used for the various metrics come from.
### VALSO
#### Transports
The **ACC transport** value is taken from *Donohue, K. A., Tracey, K. L., Watts, D. R., Chidichimo, M. P., 
and Chereskin, T. K.: "Mean Antarctic Circumpolar Current transport measured in Drake Passage", Geophysical Research 
Letters, 43, 11,760–11,767, https://doi.org/https://doi.org/10.1002/2016GL070319, (2016)*.

The **Weddell Gyre strength** is taken from *Klatt, O., Fahrbach, E., Hoppema, M., and Rohardt, G.: "The transport of 
the Weddell Gyre across the Prime Meridian", Deep Sea Research Part II: Topical Studies in Oceanography, 52, 513–528, 
https://doi.org/https://doi.org/10.1016/j.dsr2.2004.12.015, "Direct observations of
oceanic flow: A tribute to Walter Zenk" (2005)*. The model metric is the peak positive value of the streamfunction 
integrating from the southern boundary. It therefore includes the transport of the Antarctic Shelf Current and the 
recirculating gyre. The *Klatt et al* measurement is comparable to this. 

The **Ross Gyre strength** is taken from *Dotto, T. S., Naveira Garabato, A., Bacon, S., Tsamados, M., Holland, P. R., 
Hooley, J., Frajka-Williams, E., Ridout, A., and Meredith, M. P.: "Variability of the Ross Gyre, Southern Ocean: Drivers 
and Responses Revealed by Satellite Altimetry", Geophysical Research Letters, 45,
6195–6204, https://doi.org/https://doi.org/10.1029/2018GL078607 (2018)*. In this case they measure the transport of the 
recirculating gyre and the throughflow (Shelf current) separately so I have added these values in order to compare to 
the model. The variability (standard deviation) of the observations is only quoted for the recirculating gyre 
so I have used this value.  


#### Shelf temperatures and salinities
The original version of VALSO took average bottom salinities and temperatures over the four boxes defined on the shelf.
There was no reference for the corresponding observational values (just P.Mathiot), so as of June 2023 I have updated
these to use means over deep boxes (below 400m) instead. For the observational comparison I have used the EN4.2.2.g10 profile
dataset which is probably more reliable than the EN4 analysis in this region. I took means and standard deviations for 
all the profiles with data below 400m in the defined boxes (see the script mk_deepTS.bash for the box lat/lon limits).
Because the time and depth sampling of the profiles is uneven I weighted the statistics by month and depth: I calculated
means and variances for each month and for 100m depth bins and then took the means of these to give the overall mean and 
variance. 

Note that the final values used for the means of the observations don't differ much from the original 
observational values for the bottom fields (meaning that Pierre's expert judgment was reasonable) and the change in the 
calculation of the model metrics from using averages of bottom fields to averages of deep boxes doesn't generally
seem to make much difference to these values either (meaning that the deep water isn't very stratified). So the net 
result is that updating your VALSO calculations to use the new metrics will (probably) not make a material difference to
the conclusions you draw, but will make it a bit easier to include the plots in papers.

The pictures here are from a presentation I gave and give some indication of the time distribution of the profiles 
and the distribution in temperature and salinity space. The first set of plots shows the time distribution of all the 
available EN4 profiles, the
lines colour coded by month. For the EROSS and WWED areas the profiles consist mainly of CTD measurements from cruises 
and are weighted heavily towards the summer. When the EROSS and WWED metrics are calculated for the model fields we use
DJF means rather than annual means to make the comparison with obs more valid. For the AMU and WROSS regions there is 
good coverage through out the year for some recent years. For these regions the data is mainly seal data. Weddell seals 
dive surprisingly deep - up to 700m. 

![Alt text](FIGURES/profiles_timeseries.jpg?raw=true "Timeseries of numbers of profiles by month and year.")

The second set of plots shows the distribution of all observations within the relevant boxes (although note that for 
these plots I used a top-of-box depth of 300m whereas in the end I settled on 400m). The number of obs reduces with 
increasing depth as you might expect but it is encouraging to note that the deepest values appear to converge in all 
cases. The third set of plots show model bathymetries (from eORCA12) for the four areas and you can see that the depth
coverage of the observations is good in all cases. The shelves around Antarctica are generally deep - of order 500m - 
and in the AMU and WROSS regions there are deep trenches to over 1000m.

![Alt text](FIGURES/profiles_scatter_plot.jpg?raw=true "Scatter plots of profiles for all times.")
![Alt text](FIGURES/shelf_bathymetries.jpg?raw=true "Model bathymetry (eORCA12) in shelf boxes.")

*References:*
 * *Good, S. A., Martin, M. J., and Rayner, N. A.: "EN4: quality controlled ocean temperature and salinity 
profiles and monthly objective analyses with uncertainty estimates", J. Geophys. Res.-Oceans, 118, 6704–6716,
https://doi.org/10.1002/2013JC009067, 2013*
 * *Storkey et al: to be submitted to GMD*
#### Weddell mixed layer depth
TBD

### VALNA
TBD

### VALTRANS
TBD
<a name="authors"></a>
## Authors
* [pmathiot](https://github.com/pmathiot)
* [sophmm](https://github.com/sophmm)
* [DaveStorkey](https://github.com/DaveStorkey)

<a name="licence"></a>
## Licence

[comment]: <> ([![License: MIT]&#40;https://img.shields.io/badge/License-MIT-yellow.svg&#41;]&#40;https://opensource.org/licenses/MIT&#41;)

<a name="acknowledgement"></a>
## Acknowledgements
* This is the Met Office development of the original VALSO code by Pierre Mathiot.
  Pierre's repository is [here](https://github.com/pmathiot/VALSO)


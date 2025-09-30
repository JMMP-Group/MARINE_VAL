#!/usr/bin/env python

import glob
import sys
import numpy as np
import xarray as xr
import argparse
from matplotlib import pyplot as plt
import matplotlib.gridspec as gridspec

#=======================================================================================

def load_argument():
   # args
   parser = argparse.ArgumentParser()
   parser.add_argument("-dir", dest="datpath", metavar='data path', help="path to the data directory", type=str, nargs=1, required=True)
   parser.add_argument("-o", dest="outfile", metavar='figure_name', help="output figure name without extension", type=str, nargs=1, required=True)
   parser.add_argument("-st", dest="stem", metavar='stem', help="stem of the file name to be used in the search", type=str, nargs=1, required=True)
   parser.add_argument("-p", dest="prefix", metavar='prefix', help="prefix of the file name to be used in the search", type=str, nargs=1, required=True)
   parser.add_argument("-runid", dest="runid", metavar='runid list', help="used to look information in runid.db", type=str, nargs='+' , required=True)
   parser.add_argument("-obs", dest="obsfile", metavar='obs file', help="path to the RAPID obs file", type=str, nargs='+' , required=True)

   return parser.parse_args()

def parse_dbfile(runid):
    try:
        lstyle=False
        with open('style.db') as fid:
            for cline in fid:
                att=cline.split('|')
                if att[0].strip() == runid:
                    cpltrunid = att[0].strip()
                    cpltname  = att[1].strip()
                    cpltline  = att[2].strip()
                    cpltcolor = att[3].strip()
                    lstyle=True
        if not lstyle:
            raise Exception(runid+' not found in style.db')

    except Exception as e:
        print ('Issue with file : style.db')
        print (e)
        sys.exit(42)

    # return value
    return cpltrunid, cpltname, cpltline, cpltcolor

#=======================================================================================

args = load_argument()

cm = 1/2.54  # centimeters in inches
fig = plt.figure(figsize=(13*cm, 20*cm), dpi=200)
spec = gridspec.GridSpec(ncols=1, nrows=1, figure=fig)
ax = fig.add_subplot(spec[:1])

for e, runid in enumerate([args.runid[0]] + args.runid):
     
    if e == 0:
       # observations
       time = "time"
       z = "depth"
       moc = "stream_function_mar" 
       cpltname, cpltcolor = 'obs', 'black'
       print(f"Name: {cpltname}, Color: {cpltcolor}")
       ds = xr.open_dataset(args.obsfile[0])
    else:
       # simulations
       wrkdir = args.datpath[0] + runid + "/rapid_z/"
       time = "time_counter"
       z = "depthw"
       moc = "amoc_rapid"
       _, cpltname, _, cpltcolor = parse_dbfile(runid)
       print(f"Name: {cpltname}, Color: {cpltcolor}")
       ds = xr.open_mfdataset(wrkdir+args.prefix[0]+"*"+args.stem[0]+"*.nc",
                              combine='nested',
                              concat_dim=time
            )

    alpha = 0.2

    mocz_mean = ds[moc].mean(dim=time).squeeze().values
    mocz_std  = ds[moc].std(dim=time).values
    depth     = ds[z].values 
    ax.plot(mocz_mean, depth, color=cpltcolor, linestyle="-", linewidth=2.5, label=cpltname)
    if e == 0:
       ax.fill_betweenx(depth, 
                        mocz_mean+mocz_std, 
                        mocz_mean-mocz_std, 
                        alpha=alpha, 
                        facecolor=cpltcolor
       )
    
ax.plot(mocz_mean*0.0, depth, color='black', linestyle="--", linewidth=0.5)
plt.rc('legend', **{'fontsize':12})
ax.legend(loc=1, ncol=1, frameon=False)
ax.set_xlabel('Vol. Transport [Sv]')
ax.set_ylabel('Depth [$m$]')
#ax.set_ylim(0, 28.)
#if 'east' in args.stem[0]:
#   ax.set_xlim(-4,17)
#elif 'west' in args.stem[0]:
#   ax.set_xlim(-4,9)
plt.gca().invert_yaxis()
print("Saving "+ args.outfile[0] + ".png")
plt.savefig(f"{args.outfile[0]}.png")



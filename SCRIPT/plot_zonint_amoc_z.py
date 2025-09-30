#!/usr/bin/env python

import glob
import sys
import numpy as np
import xarray as xr
import argparse
from matplotlib import pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.colors import TwoSlopeNorm
#from matplotlib.colors import LinearSegmentedColormap

#=======================================================================================

def load_argument():
   # args
   parser = argparse.ArgumentParser()
   parser.add_argument("-dir", dest="datpath", metavar='data path', help="path to the data directory", type=str, nargs=1, required=True)
   parser.add_argument("-o", dest="outfile", metavar='figure_name', help="output figure name without extension", type=str, nargs=1, required=True)
   #parser.add_argument("-st", dest="stem", metavar='stem', help="stem of the file name to be used in the search", type=str, nargs=1, required=True)
   parser.add_argument("-p", dest="prefix", metavar='prefix', help="prefix of the file name to be used in the search", type=str, nargs=1, required=True)
   parser.add_argument("-runid", dest="runid", metavar='runid list', help="used to look information in runid.db", type=str, nargs='+' , required=True)

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

for e, runid in enumerate(args.runid):

    cm = 1/2.54  # centimeters in inches
    fig = plt.figure(figsize=(20*cm, 13*cm), dpi=200)
    spec = gridspec.GridSpec(ncols=1, nrows=1, figure=fig)
    ax = fig.add_subplot(spec[:1])
     
    wrkdir = args.datpath[0] + "/" + runid + "/amoc_z/"
    time   = "time_counter"
    depth  = "depthw"
    latit  = 'nav_lat'
    amoc   = "zomsfatl"

    file_list = wrkdir + args.prefix[0] + "*.nc"

    ds = xr.open_mfdataset(file_list,
                           combine='nested',
                           concat_dim=time
    ).squeeze(dim='x')

    amocz_avg = ds[amoc].mean(dim=time)
    amocz_avg = amocz_avg.where(amocz_avg != 0.)
    ref_latit = ds[latit].isel(time_counter=0)
    ref_depth = ds[depth]
    ref_lat, ref_dep = xr.broadcast(ref_latit, ref_depth)
    lev = np.arange(-5.,17.,1.)
    cmap = "RdYlBu_r"

    norm = TwoSlopeNorm(vmin=np.nanmin(amocz_avg.values), vcenter=0, vmax=np.nanmax(amocz_avg.values))
    plt1 = ax.contourf(ref_lat.T, ref_dep.T, amocz_avg, lev, norm=norm, cmap=cmap) 
    plt.colorbar(plt1, label='AMOC (Sv)')

    cs = ax.contour(ref_lat.T, ref_dep.T,
                    amocz_avg, levels=lev,
                    linewidths=0.5,
                    colors="gray"
                   )
    cn_lev = np.arange(-6.,25.,5.)
    cs = ax.contour(ref_lat.T, ref_dep.T, 
                    amocz_avg, levels=cn_lev,
                    linewidths=1,
                    colors="black"
                   )
    cb = ax.clabel(cs, colors=['black'], inline=0, inline_spacing=-10, fmt=' {:.0f} '.format, fontsize=12)
    [txt.set_bbox(dict(boxstyle='square,pad=0',fc='w')) for txt in cb]
    
    ax.set_xlabel('Latitude')
    ax.set_ylabel(r'Depth [$m$]')
    ax.set_xlim(-30,80)
    plt.gca().set_facecolor("black")
    print(runid + "_" + args.outfile[0] + ".png")
    plt.savefig(runid + "_" + args.outfile[0] + ".png")


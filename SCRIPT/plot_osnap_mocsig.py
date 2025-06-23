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
     
    wrkdir = args.datpath[0] + "/" + runid + "/"
    time = "t"
    sigm = "rho_bins"
    moc = "osnap_moc_sig"

    # observations 
    if e == 0:
       obs_stem = 'obs_west' if 'west' in args.stem[0] else 'obs_east'
       cpltname, cpltcolor = 'obs', 'black'
       print(f"Name: {cpltname}, Color: {cpltcolor}")
       ds = xr.open_dataset(wrkdir+args.prefix[0]+"_"+obs_stem+".nc")
    else:
       # projections
       _, cpltname, _, cpltcolor = parse_dbfile(runid)
       print(f"Name: {cpltname}, Color: {cpltcolor}")
       ds = xr.open_mfdataset(wrkdir+args.prefix[0]+"*"+args.stem[0]+".nc",combine='nested',concat_dim="t")

    alpha = 0.2

    mocsig_mean = ds[moc].mean(dim=time).values
    mocsig_std = ds[moc].std(dim=time).values
    sigma = ds[sigm].values 
    if e == 0: mocsig_mean = -mocsig_mean # / 10**6
    #if e == 1 or e == 3 or e == 5: mocsig_mean = -mocsig_mean
 
    #if e == 0:
    ax.plot(mocsig_mean, sigma, color=cpltcolor, linestyle="-", linewidth=2.5, label=cpltname)
    #else:
    #   ax.plot(mocsig_mean, sigma, color=col[e], linestyle="--", linewidth=2.0, label=lab[e])
    if e == 0:
       ax.fill_betweenx(sigma, mocsig_mean+mocsig_std, mocsig_mean-mocsig_std, alpha=alpha, facecolor=cpltcolor)
    
ax.plot(mocsig_mean*0.0, sigma, color='black', linestyle="--", linewidth=0.5)
plt.rc('legend', **{'fontsize':12})
ax.legend(loc=1, ncol=1, frameon=False)
ax.set_xlabel('Vol. Transport [Sv]')
ax.set_ylabel(r'$\sigma_{\theta}$ [$kg\;m^{-3}$]')
#ax.set_ylim(25.5, 28.2)
#ax.set_ylim(22., 28.5)
ax.set_ylim(26.8, 28.)
#ax.set_xlim(-4,17)
ax.set_xlim(-4,9)
plt.gca().invert_yaxis()
# name = 'osnap_mocsig.png'
#name = 'osnap_mocsig_damp.png'
plt.savefig(f"{args.outfile[0]}.png")



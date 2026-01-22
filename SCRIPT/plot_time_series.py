import numpy as np
import glob
import netCDF4 as nc
import matplotlib.pyplot as plt
import matplotlib.colors as colors
import sys
import re
import datetime as dt
import argparse
import pandas as pd
import matplotlib.dates as mdates
import matplotlib.ticker as ticker

# def class runid
class run(object):
    def __init__(self, runid, sf):
        # parse dbfile
        self.runid, self.name, self.line, self.color = parse_dbfile(runid)
        self.sf = sf

    def load_time_series(self, cfile, cvar):
        # need to deal with mask, var and tag
        # need to do with the cdftools unit -> no unit !!!!
        # define time variable
        ctime = 'time_centered'

        # define unit
        nf = len(cfile)
        df=[None]*nf
        for kf,cf in enumerate(cfile):
            try:
                ncid    = nc.Dataset(cf)
                ncvtime = ncid.variables[ctime]
                if 'units' in ncvtime.ncattrs():
                    cunits = ncvtime.units
                else:
                    cunits = "seconds since 1900-01-01 00:00:00"
                # define calendar
                if 'calendar' in ncvtime.ncattrs():
                    ccalendar = ncvtime.calendar
                else:
                    ccalendar = "noleap"
                time = nc.num2date(ncid.variables[ctime][:].squeeze(), cunits, ccalendar)
                
                # convert to proper datetime object
                if isinstance(time,(list,np.ndarray)):
                    ntime = time.shape[0]
                else:
                    time=[time]
                    ntime = 1
    
                timeidx=[None]*ntime
                for itime in range(0, ntime):
                    # Convert to python datetime format. Better to use this than pandas Timestamp
                    # because the latter has a restriction on the total time range of ~500 years.
                    timeidx[itime] = dt.datetime(time[itime].year,time[itime].month,time[itime].day)
                        
                # build series
                cnam=get_varname(cf,cvar)
                df[kf] = pd.Series(ncid.variables[cnam][:].squeeze()*self.sf, index = timeidx, name = self.name)

            except Exception as e: 
                print ('issue in trying to load file : '+cf)
                print (e)
                sys.exit(42) 


        # build dataframe
        self.ts   = pd.DataFrame(pd.concat(df)).sort_index()
        self.mean = self.ts[self.name].mean()
        self.std  = self.ts[self.name].std()
        self.min  = self.ts[self.name].min()
        self.max  = self.ts[self.name].max()

    def __str__(self):
        return 'runid = {}, name = {}, line = {}, color = {}'.format(self.runid, self.name, self.line, self.color)

def get_name(regex,varlst):
    revar = re.compile(r'\b%s\b'%regex,re.I)
    cvar  = revar.findall(','.join(varlst))
    if (len(cvar) > 1):
        print (regex+' name list is longer than 1 or 0; error')
        print (cvar[0]+' is selected')
    if (len(cvar) == 0):
        print ('no match between '+regex+' and :')
        print (varlst)
        sys.exit(42)
    return cvar[0]

def get_varname(cfile,cvar):
    ncid   = nc.Dataset(cfile)
    cnam=get_name(cvar,ncid.variables.keys())
    ncid.close()
    return cnam

#=============================== obs management =================================
def load_obs(cfile):
    print ('open file '+cfile)
    with open(cfile) as fid:
        cmean = find_key('mean', fid)
        cstd  = find_key('std' , fid)
        cmin  = find_key('min' , fid)
        cmax  = find_key('max' , fid)
    return cmean, cstd, cmin, cmax

def find_key(char, fid):
    fid.seek(0)
    for cline in fid:
        lmatch = re.findall(char, cline) 
        if (lmatch) :
            key = cline.rstrip().strip('\n').split(' ')[-1]
            # convert to float if possible otherwise return string:
            try:
                key = float(key)
            except ValueError:
                pass
            return key
    else:
        return None
#================================================================================

# check argument
def load_argument():
    # deals with argument
    parser = argparse.ArgumentParser()
    parser.add_argument("-runid", metavar='runid list' , help="used to look information in runid.db"                  , type=str, nargs='+' , required=True )
    parser.add_argument("-f"    , metavar='file list'  , help="file list to plot (default is runid_var.nc)"           , type=str, nargs='+' , required=False)
    parser.add_argument("-var"  , metavar='var list'   , help="variable to look for in the netcdf file ./runid_var.nc", type=str, nargs='+' , required=True )
    parser.add_argument("-varf" , metavar='var list'   , help="variable to look for in the netcdf file ./runid_var.nc", type=str, nargs='+' , required=False)
    parser.add_argument("-title", metavar='title'      , help="subplot title (associated with var)"                   , type=str, nargs='+' , required=False)
    parser.add_argument("-dir"  , metavar='directory of input file' , help="directory of input file"                  , type=str, nargs=1   , required=False, default=['./'])
    parser.add_argument("-sf"  , metavar='scale factor', help="scale factor"                             , type=float, nargs=1   , required=False, default=[1])
    parser.add_argument("-o"    , metavar='figure_name', help="output figure name without extension"                  , type=str, nargs=1   , required=False, default=['output'])
    # flag argument
    parser.add_argument("-obs"  , metavar='obs mean and std file', help="obs mean and std file"          , type=str, nargs='+', required=False)
    parser.add_argument("-mean" , help="will plot model mean base on input netcdf file"                               , required=False, action="store_true")
    parser.add_argument("-noshow" , help="do not display the figure (only save it)"                                   , required=False, action="store_true")
    parser.add_argument("-force_zero_origin" , help="force the y-origin to be at zero"                                , required=False, action="store_true")
    return parser.parse_args()

def output_argument_lst(cfile, arglst):
    fid = open(cfile, "w")
    fid.write(' python2.7 '+' '.join(arglst))
    fid.close()

# ============================ plotting tools ==================================
def get_corner(ax):
    x0 = ax.get_position().x1
    x1 = x0+0.1
    y0 = ax.get_position().y0
    y1 = ax.get_position().y1
    return x0, x1, y0, y1

def get_ybnd(run_lst, omin, omax):
    rmin = omin; rmax = omax
    for irun in range(len(run_lst)):
        run  = run_lst[irun]
        rmin = min(rmin, run.ts[run.name].min())
        rmax = max(rmax, run.ts[run.name].max())
    return rmin, rmax

def add_legend(lg, ax, ncol=3, lvis=True):
    x0, x1, y0, y1 = get_corner(ax)
    lax = plt.axes([0.0, 0.0, 1, 0.15])
    lline, llabel = lg.get_legend_handles_labels()
    leg=plt.legend(lline, llabel, loc='upper left', ncol = ncol, fontsize=16, frameon=False)
#    for separate legend
#    leg=plt.legend(lline, llabel, loc='center left', ncol = ncol, fontsize=32, frameon=False)
    for item in leg.legend_handles:
        item.set_visible(lvis)
    lax.set_axis_off() 

def add_text(lg, ax, clabel, ncol=3, lvis=True):
    x0, x1, y0, y1 = get_corner(ax)
    lax = plt.axes([0.0, 0.0, 1, 0.15])
    lline, llabel = lg.get_legend_handles_labels()
    leg=plt.legend(lline, clabel, loc='upper left', ncol = ncol, fontsize=16, frameon=False)
    for item in leg.legend_handles:
        item.set_visible(lvis)
    lax.set_axis_off() 
# ========================== stat plot ============================
def tidyup_ax(ax, xmin, xmax, ymin, ymax):
    ax.set_ylim([ymin, ymax])
    ax.set_xlim([xmin, xmax])
    ax.set_yticklabels([])
    ax.set_xticks([])
    ax.grid()

def add_modstat(ax, run_lst):
    for irun in range(len(run_lst)):
        cpl = plt.errorbar(irun+1, run_lst[irun].mean, yerr=run_lst[irun].std, fmt='o', markeredgecolor=run_lst[irun].color, markersize=8, color=run_lst[irun].color, linewidth=2)

def add_obsstat(ax, mean, bounds):
    print('mean : ',mean)
    print('bounds : ',bounds)
    cpl = plt.errorbar(0, mean, yerr=bounds, fmt='*', markeredgecolor='k', markersize=8, color='k', linewidth=2)

# ============================ file parser =====================================
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
# ============================ file parser end =====================================

def main():

# load argument
    args = load_argument()

# output argument list
    output_argument_lst(args.o[0]+'.txt', sys.argv)

# parse db file
    nrun = len(args.runid)
    nvar = len(args.var)
    lg_lst   = [None]*nrun
    run_lst  = [None]*nrun
    ts_lst   = [None]*nrun ; style_lst = [None]*nrun ;
    ax       = [None]*nvar
    obs_mean = [None]*nvar; obs_std = [None]*nvar; obs_min = [999999.9]*nvar; obs_max = [-999999.9]*nvar
    obs_err_lower = [None]*nvar; obs_err_upper = [None]*nvar 
    rmin = [None]*nvar; rmax = [None]*nvar;

    for irun, runid in enumerate(args.runid):
        # initialise run
        run_lst[irun] = run(runid, args.sf[0])

    plt.figure(figsize=np.array([210, 210]) / 25.4)
 
# need to deal with multivar
    mintime=dt.date.max
    maxtime=dt.date.min
    ymin=-sys.float_info.max
    ymax=sys.float_info.max

    for ivar, cvar in enumerate(args.var):
        ax[ivar] = plt.subplot(nvar, 1, ivar+1)
        # load obs
        if args.obs:
            obs_mean[ivar], obs_std[ivar], obs_min[ivar], obs_max[ivar] = load_obs(args.obs[ivar])
            if obs_std[ivar] is not None:
                obs_err_lower[ivar] = obs_std[ivar]
                obs_err_upper[ivar] = obs_std[ivar]
            print('obs_mean[ivar], obs_std[ivar], obs_min[ivar], obs_max[ivar] : ',obs_mean[ivar], obs_std[ivar], obs_min[ivar], obs_max[ivar])

            if obs_min[ivar] is not None:
                obs_err_lower[ivar] = abs( obs_mean[ivar] - obs_min[ivar] )
            elif obs_std[ivar] is not None:
                obs_min[ivar] = obs_mean[ivar] - obs_std[ivar]
            else:
                obs_err_lower[ivar] = 0.0

            if obs_max[ivar] is not None:
                obs_err_upper[ivar] = abs( obs_mean[ivar] - obs_max[ivar] )
            elif obs_std[ivar] is not None:
                obs_max[ivar] = obs_mean[ivar] + obs_std[ivar]
            else:
                obs_err_upper[ivar] = 0.0
                 
        for irun, runid in enumerate(args.runid):

            # load data
            if args.f:
                # in case only one file pattern given
                if len(args.f) == 1 :
                    fglob = args.f[0]
                else :
                    fglob = args.f[irun]
                cfile = glob.glob(args.dir[0]+'/'+runid+'/'+fglob)
                if len(cfile)==0:
                    print ('no file found with this pattern '+args.dir[0]+'/'+runid+'/'+fglob)
                    sys.exit(42)
            elif args.varf:
               # in case only one file pattern given
                if len(args.varf) == 1 :
                    fglob = args.varf[0]
                else :
                    fglob = args.varf[ivar]
                cfile = glob.glob(args.dir[0]+'/'+runid+'/'+fglob)
                if len(cfile)==0:
                    print ('no file found with this pattern '+args.dir[0]+'/'+runid+'/'+fglob)
                    sys.exit(42)
            else:
                cfile = glob.glob(args.dir[0]+'/'+runid+'_'+cvar+'.nc')
                if len(cfile)==0:
                    print ('no file found with this pattern '+args.dir[0]+'/'+runid+'_'+cvar+'.nc')
                    sys.exit(42)

            run_lst[irun].load_time_series(cfile, cvar)
            ts_lst[irun] = run_lst[irun].ts
            print("run_lst[irun] min/max : ",run_lst[irun].min,run_lst[irun].max)
            lg = ts_lst[irun].plot(ax=ax[ivar], legend=False, style=run_lst[irun].line,color=run_lst[irun].color,label=run_lst[irun].name, x_compat=True, linewidth=2, rot=0)
            #
            # limit of time axis
            mintime=min([mintime,ts_lst[irun].index[0].date()])
            maxtime=max([maxtime,ts_lst[irun].index[-1].date()])
            print("mintime, maxtime : ",mintime,maxtime)

        # set title
        if (args.title):
            ax[ivar].set_title(args.title[ivar],fontsize=20)

        # set x axis
        nlabel=5
        ndays=(maxtime-mintime).days
        nyear=ndays/365
        print('nyear : ',nyear)
        for nyt in [1,2,5,10,20,50,100,200,500]:
            if nyear/nyt < 8:
                break
        print('nyt : ',nyt)
        nmt=ts_lst[irun].index[0].date().month
        ndt=ts_lst[irun].index[0].date().day
         
        ax[ivar].xaxis.set_major_locator(mdates.YearLocator(nyt,month=1,day=1))
        ax[ivar].tick_params(axis='both', labelsize=16)
        if (ivar != nvar-1):
            ax[ivar].set_xticklabels([])
        else:
            ax[ivar].xaxis.set_major_formatter(mdates.DateFormatter('%Y'))

        for lt in ax[ivar].get_xticklabels():
            lt.set_ha('center')
 
        rmin[ivar],rmax[ivar]=get_ybnd(run_lst,obs_min[ivar],obs_max[ivar])
        if args.force_zero_origin:
            rmin[ivar]=0.0
        ax[ivar].set_ylim([rmin[ivar],rmax[ivar]])
        ax[ivar].grid()
 
    # tidy up space
    plt.subplots_adjust(left=0.1, right=0.8, bottom=0.2, top=0.92, wspace=0.15, hspace=0.15)

    # add legend
    add_legend(lg,ax[nvar-1])

    if args.mean or args.obs:
        xmin = 0 ; xmax = 0
        for ivar, cvar in enumerate(args.var):
            x0, x1, y0, y1=get_corner(ax[ivar])    
            cax = plt.axes([x0+0.01, y0, x1-x0, y1-y0])
            # plot obs mean
            if args.obs:
                xmin = min(xmin, -1)
                xmax = max(xmax,  1)
                print([[obs_min[ivar]],[obs_max[ivar]]])
                add_obsstat(cax, obs_mean[ivar], [[obs_err_lower[ivar]],[obs_err_upper[ivar]]] ) 
            # plot mean model
            if args.mean:
                xmax = max(xmax, len(run_lst)+1)
                # rebuild run_lst for the mean (not optimale but fast enough for the application)
                for irun, runid in enumerate(args.runid):
                    # load data
                    cfile = args.dir[0]+'/'+runid+'_'+cvar+'.nc'
                    run_lst[irun].load_time_series(cfile, cvar)
                # add mean and std
                add_modstat(cax, run_lst)
            # set min/max/grid ...
            tidyup_ax(cax, xmin, xmax, rmin[ivar], rmax[ivar])

    plt.savefig(args.o[0]+'.png', format='png', dpi=150)

    if args.noshow: 
       pass
    else:
       plt.show()

    # build specific legend figure 
    # (for bottom of standard VALSO-type plots)
    plt.figure(figsize=np.array([210*3, 210*3]) / 25.4)
    ax = plt.subplot(1, 1, 1)
    ax.axis('off')
    add_legend(lg,ax,ncol=4)
    plt.savefig('legend.png', format='png', dpi=150)

    # build specific legend figure
    # (with one dataset per line - useful for publication figures)
    plt.figure(figsize=np.array([210*3, 210*3]) / 25.4)
    ax = plt.subplot(1, 1, 1)
    ax.axis('off')
    add_legend(lg,ax,ncol=1)
    plt.savefig('legend_one_dataset_per_line.png', format='png', dpi=150)

    # build specific text figure
    plt.figure(figsize=np.array([210*3, 210*3]) / 25.4)
    ax = plt.subplot(1, 1, 1)
    ax.axis('off')
    clabel=['']*len(args.runid)
    for irun, runid in enumerate(args.runid):
        clabel[irun]=run_lst[irun].name+' = '+runid
    add_text(lg,ax,clabel,ncol=4,lvis=False)
    plt.savefig('runidname.png', format='png', dpi=150)

if __name__=="__main__":
    main()

import glob
import os

suite = 'u-cq525'
dir_in_SO = '/scratch/hadom/MARINE_VAL/VALSO/'+suite
dir_in_NA = '/scratch/hadom/MARINE_VAL/VALNA/'+suite

def do_SO_psi(dir_in):
    files = sorted(glob.glob(os.path.join(dir_in, '*_psi.nc')))
    for f in files:
        cmd = 'ncatted -a valid_min,max_sobarstf,d,, -a valid_max,max_sobarstf,d,, '+f
        print(cmd)
        os.system(cmd)

def do_SO_wmxl(dir_in):
    files = sorted(glob.glob(os.path.join(dir_in, 'WMXL*.nc')))
    for f in files:
        cmd = 'ncatted -a valid_max,max_somxzint1,d,, '+f
        print(cmd)
        os.system(cmd)
   
def do_NA_psi(dir_in):
    files = sorted(glob.glob(os.path.join(dir_in, 'BSF*_psi.nc')))
    for f in files:
        cmd = 'ncatted -a valid_min,min_sobarstf,d,, -a valid_max,min_sobarstf,d,, '+f
        print(cmd)
        os.system(cmd)

def do_NA_mxl(dir_in):
    files = sorted(glob.glob(os.path.join(dir_in, 'LAB_MXL*.nc')))
    for f in files:
        cmd = 'ncatted -a valid_min,mean_somxl030,d,, -a valid_max,mean_somxl030,d,, '+f
        print(cmd)
        os.system(cmd)



if __name__ == '__main__':
    #do_SO_psi(dir_in_SO)
    #do SO_wmxl(dir_in_SO)
    do_NA_psi(dir_in_NA)
    do_NA_mxl(dir_in_NA)

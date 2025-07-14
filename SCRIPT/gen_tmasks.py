'''
Routine to generate tmask files for processes defined
@author: Hatim Chahout
'''

import argparse
import subprocess
import os
import time
import json

def source_param(param_file_path):
    """Source a bash script and return all variables with the prefix 'run'."""
    command = f"bash -c 'source {param_file_path} && declare -p'"
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, executable='/bin/bash')
    output, error = proc.communicate()

    if proc.returncode != 0:
        print(f"Error sourcing {param_file_path}: {error.decode('utf-8')}")
        raise RuntimeError(f"Failed to source {param_file_path}")

    env = {}
    for line in output.decode('utf-8').splitlines():
        if line.startswith("declare"):
            key, _, value = line.partition("=")
            key = key.split()[-1]
            value = value.strip('"')
            if key[:3].lower() == "run":
                env[key] = value  

    return env

def domain_params(domain_name):
     return {**domains[domain_name], **{"o": domain_name}}

def load_argument():
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", dest="runid", metavar="runid", type=str, nargs=1, required=True)
    return parser.parse_args()

args = load_argument()

processes = source_param(os.path.join(os.environ['MARINE_VAL'],'param.bash')) # load run environment variables
print(f"Loaded environment variables from param.bash: \n{processes}\n")

run_path = os.path.join(os.environ['DATPATH'], args.runid[0])
mesh_path = os.path.join(run_path, 'mesh.nc')
obs_path = "/data/users/nemo/obs_data/NOAA_WOA13v2/1955-2012/025/orca025"
obs_meshf = "mesh_mask_eORCA025_v3.2_r42.nc"
obs_mesh_path = os.path.join(run_path, obs_meshf)

if not os.path.exists(obs_mesh_path):
    print(f"Linking files: \n{os.path.join(obs_path, obs_meshf)}\n--> {obs_mesh_path}")
    os.symlink(os.path.join(obs_path, obs_meshf), obs_mesh_path)

domains = {
      "AMU": {"W": -109.640, "E": -102.230, "S": -75.800, "N": -71.660, "tlon": -106, "tlat": -74},
      "EROSS": {"W": -176.790, "E": -157.820, "S": -78.870, "N": -77.520, "tlon": -167, "tlat": -78},
      "LAB_SEA": {"W": -60.000, "E": -50.000, "S": 55.000, "N": 62.000, "tlon": -55, "tlat": 58.5},
      "MEDOVF": {"W": -16.000, "E": -5.500, "S": 31.500, "N": 39.500, "tlon": -11, "tlat": 35.5},
      "NA_GYRE": {"W": -60.000, "E": -20.000, "S": 48.000, "N": 72.000, "tlon": -40, "tlat": 50},
      "NEWFOUND": {"W": -43.000, "E": -37.000, "S": 45.000, "N": 50.000, "tlon": -40, "tlat": 47.5},
      "RG": {"W": -168.500, "E": -135.750, "S": -72.650, "N": -61.600, "tlon": -152, "tlat": -67},
      "SO": {"W": -180.000, "E": 180.000, "S": -75.800, "N": -71.660, "tlon": 0, "tlat": -74},
      "SOUTHERN_OCEAN": {"W": -180.000, "E": 180.000, "S": -90.000, "N": -24.000, "tlon": 0, "tlat": -57},
      "WG": {"W": -31.250, "E": 37.500, "S": -66.500, "N": -60.400, "tlon": 3, "tlat": -63.5},
      "WROSS": {"W": 157.100, "E": 173.333, "S": -78.130, "N": -74.040, "tlon": 165, "tlat": -77},
      "WEDATL": {"W": -65.500, "E": -20.000, "S": -90.000, "N": -24.000, "tlon": -43, "tlat": -57},
      "WWED": {"W": -65.130, "E": -53.020, "S": -75.950, "N": -72.340, "tlon": -59, "tlat": -74}
}

proc_tmask_map = {
     "runAABW": [{**domain_params("WEDATL"), "mindepth": 1500, "maxdepth": None, "obs": None}, 
                 {**domain_params("SOUTHERN_OCEAN"), "mindepth": 1500, "maxdepth": None, "obs": None}],
     "runDEEPTS": [{**domain_params("AMU"), "mindepth": 390, "maxdepth": None, "obs": None}, 
                   {**domain_params("WROSS"), "mindepth": 390, "maxdepth": None, "obs": None}, 
                   {**domain_params("EROSS"), "mindepth": 390, "maxdepth": None, "obs": None},
                   {**domain_params("WWED"), "mindepth": 390, "maxdepth": None, "obs": None}],
     "runHTC": [{**domain_params("NA_GYRE"), "minisobath": 1000, "maxisobath": None, "obs": None},
                {**domain_params("NA_GYRE"), "minisobath": 1000, "maxisobath": None, "obs": 'woa13v2'}],
     "runMedOVF": [{**domain_params("MEDOVF"), "mindepth": 500, "maxdepth": 2500, "obs": None}, 
                   {**domain_params("MEDOVF"), "mindepth": 500, "maxdepth": 2500, "obs": 'woa13v2'}], 
     "runMLD_LabSea": [{**domain_params("LAB_SEA"), "minisobath": 1000, "maxisobath": None, "obs": None}],
     "runMLD_Weddell": [{**domain_params("WG"), "minisobath": 1000, "maxisobath": None, "obs": None}],
     "runBSF_NA": [{**domain_params("NA_GYRE"), "minisobath": 1000, "maxisobath": None, "obs": None}],
     "runBSF_SO": [{**domain_params("WG"), "minisobath": 1000, "maxisobath": None, "obs": None}, 
                   {**domain_params("RG"), "minisobath": 1000, "maxisobath": None, "obs": None}],
     "runSSS_LabSea": [{**domain_params("LAB_SEA"), "mindepth": None, "maxdepth": 1.5, "obs": None}],
     "runSST_NWCorner": [{**domain_params("NEWFOUND"), "mindepth": None, "maxdepth": 1.5, "obs": None}],
     "runSST_SO": [{**domain_params("SO"), "mindepth": None, "maxdepth": 1.5, "obs": None}],
     "runSTC": [{**domain_params("NA_GYRE"), "minisobath": 1000, "maxisobath": None, "obs": None},
                {**domain_params("NA_GYRE"), "minisobath": 1000, "maxisobath": None, "obs": 'woa13v2'}],
}

all_tmask_params = {}
tmasks_generated = {}
naming_params_order = ('obs', 'mindepth', 'minisobath', 'maxdepth', 'maxisobath')

for proc, tmask_list in proc_tmask_map.items():
     proc_tmasks_generated = []
     for params in tmask_list:
          if ('mindepth' in params or 'maxdepth' in params) and ('minisobath' in params or 'maxisobath' in params):
               raise ValueError(f"{proc}: Specify either depth constraints (mindepth/maxdepth) OR isobath constraints (minisobath/maxisobath), not both.")
          tmask_fname = '_'.join(['tmask', params['o']] + [f"{k}-{params[k]}" for k in naming_params_order if k in params and params[k] is not None]) + '.nc'
          mesh = mesh_path if params['obs'] is None else obs_mesh_path
          # Prepare parameters
          params = {k: v for k, v in params.items() if k != 'obs' and v is not None}
          params['o'] = os.path.join(run_path, tmask_fname)
          params['m'] = mesh
          param_str = ' '.join(f"-{k} {v}" for k, v in params.items())
          all_tmask_params[tmask_fname] = params # Update all params to save later
          # Generate tmask 
          if proc in processes.keys() and int(processes[proc]) == 1:
               print(f"Generating {tmask_fname} ...")
               print(f"param_string: {param_str}")
               proc_tmasks_generated.append(tmask_fname)
               start_time = time.time()
               subprocess.run(["python", os.path.join(os.environ["SCRPATH"], "tmask_zoom.py"), *param_str.split()])
               elapsed = time.time() - start_time
               print(f"{tmask_fname} generated in {elapsed:.2f} seconds.\n")
          elif proc not in processes.keys():
               print(f"{proc} not found in param.bash\n")
     # Store generated tmasks for each process
     if proc_tmasks_generated:               
          tmasks_generated[proc]= proc_tmasks_generated

print("All tmasks parameters:")
for tmask_name, params in all_tmask_params.items():
     print(f"{tmask_name}: {params}")

print(f"\nTmasks generated python file: {set(tmask for sublist in tmasks_generated.values() for tmask in sublist)}")

with open(os.path.join(os.environ["SCRPATH"], "tmasks_all_params.json"), "w") as f:
    json.dump(all_tmask_params, f, indent=2)

with open(os.path.join(os.environ["SCRPATH"], "tmasks_generated.json"), "w") as f:
    json.dump(tmasks_generated, f, indent=2)

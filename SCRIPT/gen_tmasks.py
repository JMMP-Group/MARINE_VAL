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

proc_tmask_map = {
      "runDEEPTS": [
           {"tmask_AMU": {"mindepth": 390}}, 
           {"tmask_WROSS": {"mindepth": 390}}, 
           {"tmask_EROSS": {"mindepth": 390}},
           {"tmask_WWED": {"mindepth": 390}}
      ],
      "runHTC": [
           {"tmask_NA_gyre": {"mindepth": 1000}},
           {"tmask_NA_gyre": {"mindepth": 1000, "obs": 'woa13v2'}}
      ],
      "runMLD_LabSea": [
           {"tmask_lab_sea": {}}
      ],
      "runMLD_Weddell": [
           {"tmask_WG": {}}
      ],
      "runBSF_NA": [
           {"tmask_NA_gyre": {}}
      ],
      "runBSF_SO": [
           {"tmask_WG": {}}, 
           {"tmask_RG": {}}
      ],
      "runSSS_LabSea": [
           {"tmask_lab_sea": {"maxdepth": 1.5}}
      ],
      "runSST_NWCorner": [
           {"tmask_newfound": {"maxdepth": 1.5}}
      ],
      "runSST_SO": [
           {"tmask_SO": {"maxdepth": 1.5}}
      ],
      "runSTC": [
           {"tmask_NA_gyre": {"mindepth": 1000}},
           {"tmask_NA_gyre": {"mindepth": 1000, "obs": 'woa13v2'}}
      ],
}

tmask_params = {
      "tmask_AMU": {"W": -109.640, "E": -102.230, "S": -75.800, "N": -71.660, "tlon": -106, "tlat": -74},
      "tmask_EROSS": {"W": -176.790, "E": -157.820, "S": -78.870, "N": -77.520, "tlon": -167, "tlat": -78},
      "tmask_NA_gyre": {"W": -60.000, "E": -20.000, "S": 48.000, "N": 72.000, "tlon": -40, "tlat": 50},
      "tmask_RG": {"W": -168.500, "E": -135.750, "S": -72.650, "N": -61.600, "tlon": -152, "tlat": -67},
      "tmask_lab_sea": {"W": -60.000, "E": -50.000, "S": 55.000, "N": 62.000, "tlon": -55, "tlat": 58.5},
      "tmask_newfound": {"W": -43.0, "E": -37.0, "S": -45.0, "N": 50.0, "tlon": -40, "tlat": 2.5},
      "tmask_SO": {"W": -180.0, "E": 180.0, "S": -75.800, "N": -71.660, "tlon": 0, "tlat": -74},
      "tmask_WG": {"W": -31.250, "E": 37.500, "S": -66.500, "N": -60.400, "tlon": 3, "tlat": -63.5},
      "tmask_WROSS": {"W": 157.100, "E": 173.333, "S": -78.130, "N": -74.040, "tlon": 165, "tlat": -77},
      "tmask_WWED": {"W": -65.130, "E": -53.020, "S": -75.950, "N": -72.340, "tlon": -59, "tlat": -74}
}

all_tmask_params = {}
tmasks_generated = []
extra_params_order = ('obs', 'mindepth', 'maxdepth')

for proc, tmask_list in proc_tmask_map.items():
     for tmask_dict in tmask_list:
          for tmask, extra_params in tmask_dict.items():
               assert all(k in extra_params_order for k in extra_params.keys()), f"Unexpected parameter(s) in gen_tmasks.py: {set(extra_params.keys()) - set(extra_params_order)}"
               extra_params = {k: extra_params[k] for k in extra_params_order if k in extra_params.keys()} # For filename generation
               tmask_fname = '_'.join([tmask]+[f"{k}-{v}" for k, v in extra_params.items()]) + '.nc' if extra_params else tmask + '.nc'
               mesh = mesh_path if 'obs' not in extra_params.keys() else obs_mesh_path
               # Prepare parameters
               params = {**tmask_params[tmask], **extra_params}
               params = {k: v for k, v in params.items() if k != 'obs'}
               params['o'] = os.path.join(run_path, tmask_fname)
               params['m'] = mesh
               param_str = ' '.join(f"-{k} {v}" for k, v in params.items())
               all_tmask_params[tmask_fname] = params # Update all params to save later
               # Generate tmask 
               if proc in processes.keys() and int(processes[proc]) == 1:
                    print(f"Generating {tmask_fname} ...")
                    print(f"param_string: {param_str}")
                    tmasks_generated.append(tmask_fname)
                    start_time = time.time()
                    subprocess.run(["python", os.path.join(os.environ["SCRPATH"], "tmask_zoom.py"), *param_str.split()])
                    elapsed = time.time() - start_time
                    print(f"{tmask_fname} generated in {elapsed:.2f} seconds.\n")
               elif proc not in processes.keys():
                    print(f"{proc} not found in param.bash\n")

print("All tmasks parameters:")
for tmask_name, params in all_tmask_params.items():
     print(f"{tmask_name}: {params}")

print(f"Tmasks generated python file: {set(tmasks_generated)}")

with open(os.path.join(os.environ["SCRPATH"], "tmasks_all_params.json"), "w") as f:
    json.dump(all_tmask_params, f, indent=2)

with open(os.path.join(os.environ["SCRPATH"], "tmasks_generated.json"), "w") as f:
    json.dump(list(set(tmasks_generated)), f, indent=2)

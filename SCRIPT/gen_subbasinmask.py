import xarray as xr # 2025.1.2
import numpy as np # 2.2.3
import argparse # 1.1
from util import get_ij_from_lon_lat, get_poly_line_ij, floodfill

def load_argument():
    parser = argparse.ArgumentParser()
    parser.add_argument("-m", 
                        "--mesh", 
                        dest="mesh", 
                        metavar="mesh file", 
                        help="the mesh file to work from", 
                        type=str, 
                        nargs=1 , 
                        required=True
    )
    parser.add_argument("-o", 
                        "--outf", 
                        dest="outf", 
                        metavar="output file", 
                        help="name of output file", 
                        type=str, 
                        nargs=1, 
                        required=True
    )
    return parser.parse_args()

def main():

    args = load_argument()
    mesh = xr.open_dataset(args.mesh[0]).squeeze()
    zdim = ""
    for k in ["nav_lev","z"]:
        if k in mesh: 
           zdim = k
           break
    assert zdim != "", "Vertical dimension not found in " + args.mesh[0]
    tmsk = mesh['tmask'].isel({zdim : 0})

    # Saving global mask
    glomsk = tmsk.rename('glomsk')
    

    # Saving pacific, indian and southern oceans mask
    # Since we don't use them, we put all of them to zero.
    indmsk = pacmsk = somsk = tmsk.copy()*0
    indmsk = indmsk.rename('indmsk')
    pacmsk = pacmsk.rename('pacmsk')
    somsk = somsk.rename('somsk')

    # Creating mask for the Atlantic
    # a) Closing the Med
    atlmsk = tmsk.rename('atlmsk')
    lon1 = -6.1536
    lat1 = 37.6231
    lon2 = -6.2156
    lat2 = 33.8010
    
    j1, i1 = get_ij_from_lon_lat(lon1, 
                                 lat1, 
                                 mesh.glamt.values, 
                                 mesh.gphit.values
    )
    j2, i2 = get_ij_from_lon_lat(lon2, 
                                 lat2, 
                                 mesh.glamt.values, 
                                 mesh.gphit.values
    )
    Js, Is = get_poly_line_ij([i1, i2], 
                              [j1, j2]
                             )
    atlmsk[Js,Is] = 0
    # b) Only the Atlantic northern than 34.0 South
    atlmsk = atlmsk.where(mesh.gphit>=-34.0,0)
    jstart, istart = get_ij_from_lon_lat(-38.2784, 
                                          36.3402, 
                                          mesh.glamt.values, 
                                          mesh.gphit.values
    )
    wrk = floodfill(atlmsk,
                    jstart,
                    istart,
                    0,
                    2
    )
    atlmsk = atlmsk.where(wrk==2,0)

    xr.merge([glomsk, atlmsk, indmsk, pacmsk, somsk]).to_netcdf(args.outf[0])
    

if __name__=="__main__":
    main() 

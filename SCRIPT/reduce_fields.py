#! /usr/bin/env python

'''
Wrapper to make it easy to call cube.collapsed from the command line. 

@author: Dave Storkey
@date: March 2025
'''

import iris
import iris.analysis
import iris.util
import numpy as np
import numpy.ma as ma

def read_cube(filename,fieldname):
    '''
    Read a variable from a netcdf file as an Iris cube.
    Try to match name to standard_name, long_name or var_name
    Remove duplicate time dimension if necessary.
    '''

    constraints = [ iris.NameConstraint(standard_name=fieldname),
                    iris.NameConstraint(long_name=fieldname),
                    iris.NameConstraint(var_name=fieldname) ]

    for constraint in constraints:
        try:
            cube = iris.load_cube(filename, constraint)
        except iris.exceptions.ConstraintMismatchError:
            pass
        else:
            break
    else:
        raise Exception("Could not find field ",fieldname," in file ",filename)

    for coord in cube.coords(dim_coords=True):
        if coord.var_name == "time_counter":
            cube.remove_coord(coord)
            iris.util.promote_aux_coord_to_dim_coord(cube,"time")
            break

    return cube

def get_weights(wgtsfile,wgtsname,cube):
    '''
    Try to read in a weights field from the specified file, or if the 
    file is specified as "measures", try to read the weights field as
    a CellMeasure of the supplied cube.
    '''

    if wgtsfile == "measures":
        for cell_measure in cube.cell_measures():
            if cell_measure.standard_name == wgtsname:
                wgts = cell_measure.core_data()
                break
            else:
                pass
        else:
            raise Exception("Could not find "+wgtsname+" in cell measures of "+cube.var_name)
    else:
        wgts = read_cube(wgtsfile,wgtsname)
    
    return wgts

def reduce_fields(infile,tmask,invars=None,coords=None,wgtsfiles=None,wgtsnames=None,
                  aggr=None,outfile=None,subout=None):

    aggregators = { "mean"     :  iris.analysis.MEAN ,
                    "min"      :  iris.analysis.MIN  ,
                    "max"      :  iris.analysis.MAX    }

    if infile is None:
        raise Exception("Error: must specify input file")

    if aggr is None:
        aggr="mean"

    if outfile is None:
        outfile=".".join(infile.split(".")[:-1])+"_reduced."+infile.split(".")[-1]

    if invars is None:
        cubes = iris.load(infile)
    else:
        cubes = [read_cube(infile,varname) for varname in invars]
        
    # Filter for subdomain
    tmask_cube = iris.load_cube(tmask[0])
    nav_lev_index = tmask_cube.coord_dims('nav_lev')[0]
    nav_lev_index = tuple([0 if i == nav_lev_index else slice(None) for i in range(tmask_cube.data.ndim)])

    for cube in cubes:
        has_depth = any(
            coord.var_name in ("deptht", "depthu", "depthv")
            for coord in (list(cube.dim_coords) + list(cube.aux_coords))
        )

        tmask_cube = tmask_cube.data if has_depth else tmask_cube.data[nav_lev_index]
        tmask_cube = np.broadcast_to(tmask_cube, cube.data.shape)
        cube.data = ma.masked_where(tmask_cube, cube.data) # mask data using tmask for lat, lon and depth
    
    if subout:
        subdomain_file=".".join(infile.split(".")[:-1])+"_subdomain."+infile.split(".")[-1]
        iris.save(cubes,subdomain_file)
        
    if coords is None:
        coords = "time"
        
    if wgtsnames is not None:
        if not isinstance(wgtsnames,list):
            wgtsnames=[wgtsnames]
        if wgtsfiles is None:
            print("No wgtsfile specified. Looking for weights in input file.")
            wgtsfiles = [infile]
        elif not isinstance(wgtsfiles,list):
            wgtsfiles=[wgtsfiles]
        if len(wgtsfiles) == 1:
            wgtsfiles = wgtsfiles*len(wgtsnames)
        wgtsfiles = [infile if wf == "self" else wf for wf in wgtsfiles]
        if len(wgtsfiles) != len(wgtsnames):
            raise Exception("Must specify one weights file or the same number as the number of weights fields")
        if len(wgtsfiles) > 1 and wgtsfiles[0] == "measures":
            # iris.analysis.maths.multiply won't work with a CellMeasure object as the first argument
            # so move it to be the last argument
            wgtsfiles.append(wgtsfiles.pop(0))
            wgtsnames.append(wgtsnames.pop(0))
        wgts_list = [get_weights(wgtsfile,wgtsname,cubes[0]) for (wgtsfile,wgtsname) in zip(wgtsfiles,wgtsnames)]
        wgts=wgts_list[0]        
        if len(wgts_list) > 1:
            for wgts_to_multiply in wgts_list[1:]:
                wgts = iris.analysis.maths.multiply(wgts, wgts_to_multiply, in_place=True)
        elif wgtsfiles[0] == "measures":
            # in this case, broadcast the weights to be the same shape as the cube... 
            wgts = ma.ones(cubes[0].shape)[:] * wgts[:]
        
        wgts = ma.masked_where(tmask_cube, wgts) # mask weights using tmask for lat, lon and depth

    else:
        wgts = None
                
    if aggr in ["min","max"]:
        # no weights keyword
        cubes_reduced=[cube.collapsed(coords, aggregators[aggr]) for cube in cubes]
    else:
        cubes_reduced=[cube.collapsed(coords, aggregators[aggr], weights=wgts) for cube in cubes]

    iris.save(cubes_reduced, outfile)


if __name__=="__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--infile", action="store", dest="infile", 
                         help="names of input file", required=True)
    parser.add_argument("-v", "--vars", action="store", dest="invars", nargs="+", 
                         help="names of input variables")
    parser.add_argument("-G", "--wgtsfiles", action="store", dest="wgtsfiles", nargs="+",
                         help="names of weights file or 'self' if input file or 'measures' if a cell measure")
    parser.add_argument("-g", "--wgtsnames", action="store", dest="wgtsnames", nargs="+",
                         help="names of weighting variable")
    parser.add_argument("-o", "--outfile", action="store", dest="outfile",
                         help="name of output file (format by extension)")
    parser.add_argument("-c", "--coords", action="store",dest="coords",nargs="+",
                         help="name of coordinates to reduce over (default time)")
    parser.add_argument("-A", "--aggr", action="store",dest="aggr",
                         help="name of aggregator: mean, max, min")
    parser.add_argument("-M", "--subout", action="store_true",dest="subout",
                         help="output fields on subdomain to file as sanity check")
    parser.add_argument("-m", "--tmask", action="store",dest="tmask", 
                         help="tmask file", nargs=1, type=str, required=True)
    args = parser.parse_args()

    reduce_fields(infile=args.infile,tmask=args.tmask,invars=args.invars,outfile=args.outfile,
                  wgtsfiles=args.wgtsfiles,wgtsnames=args.wgtsnames,coords=args.coords,aggr=args.aggr,
                  subout=args.subout)




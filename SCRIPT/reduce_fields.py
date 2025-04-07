#! /usr/bin/env python

'''
Wrapper to make it easy to call cube.collapsed from the command line. 

@author: Dave Storkey
@date: March 2025
'''

import iris
import iris.analysis
import iris.util
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

def get_subdomain(cubes,west=None,east=None,south=None,north=None,bottom=None,top=None):
    '''
    Select subdomain:
    1. For 1D coordinates use cube.extract to subset the cube.
    2. For 2D auxillary coordinates, mask points outside of the subdomain.
    '''
    
    constraints=[]
    
    if len(cubes[0].coord("longitude").points.shape) > 1:
        # lats/lons as 2D auxillary coordinates
        ones_array = ma.ones(cubes[0].data.shape)
        if west is not None or east is not None:
            lons = cubes[0].coord("longitude").points * ones_array
        if south is not None or north is not None:
            lats = cubes[0].coord("latitude").points * ones_array
    else:
        lons = None
        lats = None
            
    if bottom is not None or top is not None:
        try:
            depths = cubes[0].coord("depth").points
        except(iris.exceptions.CoordinateNotFoundError):
            raise Exception("Could not find depth coordinate for cube ",cubes[0].var_name,
                            ". Set standard_name='depth' for depth coordinate.")
        
    if west is not None:
        if lons is None:
            longitude_constraint = iris.Constraint(longitude=lambda cell: cell > west)
            cubes = [cube.extract(longitude_constraint) for cube in cubes]
            constraints.append(longitude_constraint)
        else:
            for cube in cubes:
                cube.data[:] = ma.masked_where(lons < west, cube.data[:])
    if east is not None:
        if lons is None:
            longitude_constraint = iris.Constraint(longitude=lambda cell: cell < east)
            cubes = [cube.extract(longitude_constraint) for cube in cubes]
            constraints.append(longitude_constraint)
        else:
            for cube in cubes:
                cube.data[:] = ma.masked_where(lons > east, cube.data[:])
    if south is not None:
        if lats is None:
            latitude_constraint = iris.Constraint(latitude=lambda cell: cell > south)
            cubes = [cube.extract(latitude_constraint) for cube in cubes]
            constraints.append(latitude_constraint)
        else:
            for cube in cubes:
                cube.data[:] = ma.masked_where(lats < south, cube.data[:])
    if north is not None:
        if lats is None:
            latitude_constraint = iris.Constraint(latitude=lambda cell: cell < north)
            cubes = [cube.extract(latitude_constraint) for cube in cubes]
            constraints.append(latitude_constraint)
        else:
            for cube in cubes:
                cube.data[:] = ma.masked_where(lats > north, cube.data[:])
    if bottom is not None:
        depth_constraint = iris.Constraint(depth=lambda cell: cell < bottom)
        cubes = [cube.extract(depth_constraint) for cube in cubes]
        constraints.append(depth_constraint)
    if top is not None:
        depth_constraint = iris.Constraint(depth=lambda cell: cell > top)
        cubes = [cube.extract(depth_constraint) for cube in cubes]
        constraints.append(depth_constraint)

    if cubes[0] is None:
        raise Exception("Subdomain extraction resulted in a null cube. Check your box limits and try again.")

    return cubes, constraints
        
def reduce_fields(infile=None,invars=None,coords=None,wgtsfiles=None,wgtsnames=None,
                  aggr=None,outfile=None,east=None,west=None,south=None,north=None,
                  top=None,bottom=None,subout=None):

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
        
    print("cubes read in : ",[cube.var_name for cube in cubes])

    constraints=[]
    if any([arg is not None for arg in [east,west,south,north,top,bottom]]):
        cubes, constraints = get_subdomain(cubes,east=east,west=west,south=south,north=north,
                                top=top,bottom=bottom)
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
        # Apply same subdomain extraction to the weights as we did to the field.
        # Note don't need to apply masking because a masked point multiplied by an unmasked point
        # is a masked point.
        if len(constraints) > 0:
            for constraint in constraints:
                if type(wgts) is iris.cube.Cube:
                    # only apply the contraints to the cube weights, not the "measures" weights
                    wgts = wgts.extract(constraint)
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
                         help="names of input file")
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
    parser.add_argument("-W", "--west", action="store",dest="west",type=float,
                         help="western limit of area to reduce")
    parser.add_argument("-E", "--east", action="store",dest="east",type=float,
                         help="eastern limit of area to reduce")
    parser.add_argument("-S", "--south", action="store",dest="south",type=float,
                         help="southern limit of area to reduce")
    parser.add_argument("-N", "--north", action="store",dest="north",type=float,
                         help="northern limit of area to reduce")
    parser.add_argument("-T", "--top", action="store",dest="top",type=float,
                         help="top limit of volume to reduce")
    parser.add_argument("-B", "--bottom", action="store",dest="bottom",type=float,
                         help="bottom limit of volume to reduce")
    parser.add_argument("-M", "--subout", action="store_true",dest="subout",
                         help="output fields on subdomain to file as sanity check")
    args = parser.parse_args()

    reduce_fields(infile=args.infile,invars=args.invars,outfile=args.outfile,
                  wgtsfiles=args.wgtsfiles,wgtsnames=args.wgtsnames,coords=args.coords,aggr=args.aggr,
                  south=args.south,north=args.north,west=args.west,east=args.east,
                  top=args.top,bottom=args.bottom,subout=args.subout)




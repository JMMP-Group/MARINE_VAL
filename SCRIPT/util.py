#!/usr/bin/env python

from typing import Tuple
import numpy as np
import netCDF4 as nc4
import xarray as xr
import scipy.spatial as sp
from xarray import Dataset, DataArray 
from matplotlib import pyplot as plt

#===================================================================================================
def get_ij_from_lon_lat(LON, LAT, lon, lat):
    '''
    This function finds the closest model 
    grid point i/j to a given lat/lon.

    Syntax:
    i, j = get_ij_from_lon_lat(LON, LAT, lon, lat)
   
    LON, LAT: target longitude and latitude
    lon, lat: 2D arrays of model grid's longitude and latidtude
    '''

    dist = hvrsn_dst(LON, LAT, lon, lat)

    min_dist = np.amin(dist)

    find_min = np.where(dist == min_dist)
    sort_j = np.argsort(find_min[1])

    j_indx = find_min[0][sort_j]
    i_indx = find_min[1][sort_j]

    return j_indx[0], i_indx[0]

def hvrsn_dst(lon1, lat1, lon2, lat2):
    '''
    This function calculates the great-circle distance in meters between 
    point1 (lon1,lat1) and point2 (lon2,lat2) using the Haversine formula 
    on a spherical earth of radius 6372.8 km. 

    The great-circle distance is the shortest distance over the earth's surface.
    ( see http://www.movable-type.co.uk/scripts/latlong.html)

    If lon2 and lat2 are 2D matrixes, then dist will be a 2D matrix of distances 
    between all the points in the 2D field and point(lon1,lat1).

    If lon1, lat1, lon2 and lat2 are vectors of size N dist wil be a vector of
    size N of distances between each pair of points (lon1(i),lat1(i)) and 
    (lon2(i),lat2(i)), with 0 => i > N .
    '''
    deg2rad = np.pi / 180.
    ER = 6372.8 * 1000. # Earth Radius in meters

    dlon = np.multiply(deg2rad, (lon2 - lon1))
    dlat = np.multiply(deg2rad, (lat2 - lat1))

    lat1 = np.multiply(deg2rad, lat1)
    lat2 = np.multiply(deg2rad, lat2)

    # Computing the square of half the chord length between the points:
    a = np.power(np.sin(np.divide(dlat, 2.)),2) + \
        np.multiply(np.multiply(np.cos(lat1),np.cos(lat2)),np.power(np.sin(np.divide(dlon, 2.)),2))

    # Computing the angular distance in radians between the points
    angle = np.multiply(2., np.arctan2(np.sqrt(a), np.sqrt(1. -a)))

    # Computing the distance 
    dist = np.multiply(ER, angle)

    return dist

#=======================================================================================
def floodfill(field,j,i,checkValue,newValue):
    '''
    This is a modified version of the original algorithm:

    1) checkValue is the value we do not want to change,
       i.e. is the value identifying the boundaries of the 
       region we want to flood.
    2) newValue is the new value we want for points whose initial value
       is not checkValue and is not newValue.
       N.B. if a point with initial value = to newValue is met, then the
            flooding stops. 

    Example:

    a = np.array([[0, 0, 0, 0, 0, 0, 0, 0, 0],
                  [0, 0, 3, 2, 1, 5, 6, 9, 0],
                  [0, 0, 8, 9, 0, 0, 0, 4, 0],
                  [0, 0, 8, 9, 7, 2, 3, 0, 0],
                  [0, 0, 4, 4, 0, 0, 0, 0, 0],
                  [0, 0, 0, 0, 0, 0, 0, 0, 0]])
   
    j_start = 3
    i_start = 4
    b = com.floodfill(a,j_start,i_start,0,2)
 
    b = array([[0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 2, 2, 1, 5, 6, 9, 0],
               [0, 0, 2, 2, 0, 0, 0, 4, 0],
               [0, 0, 2, 2, 2, 2, 3, 0, 0],
               [0, 0, 2, 2, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0]])

    '''
    Field = np.copy(field)

    theStack = [ (j, i) ]

    while len(theStack) > 0:
          try:
              j, i = theStack.pop()
              if Field[j,i] == checkValue:
                 continue
              if Field[j,i] == newValue:
                 continue
              Field[j,i] = newValue
              theStack.append( (j, i + 1) )  # right
              theStack.append( (j, i - 1) )  # left
              theStack.append( (j + 1, i) )  # down
              theStack.append( (j - 1, i) )  # up
          except IndexError:
              continue # bounds reached

    return Field

# =====================================================================================================
def get_poly_line_ij(points_i, points_j):
    '''
    get_poly_line_ij draw rasterised line between vector-points
    
    Description:
    get_poly_line_ij takes a list of points (specified by 
    pairs of indexes i,j) and draws connecting lines between them 
    using the Bresenham line-drawing algorithm.
    
    Syntax:
    line_i, line_j = get_poly_line_ij(points_i, points_i)
    
    Input:
    points_i, points_j: vectors of equal length of pairs of i, j
                        coordinates that define the line or polyline. The
                        points will be connected in the order they're given
                        in these vectors. 
    Output:
    line_i, line_j: vectors of the same length as the points-vectors
                    giving the i,j coordinates of the points on the
                    rasterised lines. 
    '''
    line_i=[]
    line_j=[]

    line_n=0

    if len(points_i) == 1:
       line_i = points_i
       line_j = points_j
    else:
       for fi in np.arange(len(points_i)-1):
           # start point of line
           i1 = points_i[fi]
           j1 = points_j[fi]
           # end point of line
           i2 = points_i[fi+1]
           j2 = points_j[fi+1]
           # 'draw' line from i1,j1 to i2,j2
           pj, pi = bresenham_line(i1,i2,j1,j2)
           if pi[0] != i1 or pj[0] != j1:
              # beginning of line doesn't match end point, 
              # so we flip both vectors
              pi = np.flipud(pi)
              pj = np.flipud(pj)

           plen = len(pi)

           for PI in np.arange(plen):
               line_n = PI
               if len(line_i) == 0 or line_i[line_n-1] != pi[PI] or line_j[line_n-1] != pj[PI]:
                  line_i.append(int(pi[PI]))
                  line_j.append(int(pj[PI]))


    return line_j, line_i

#=======================================================================================
def get_poly_area_ij(points_i, points_j, a_ji):
    '''
    Syntax:
    area_j, area_i = get_poly_area_ij(points_i, points_j, a_ji)

    Input:
    points_i, points_j: j,i indexes of the the points
                        defining the polygon
    a_ji: shape (i.e., (nj,ni)) of the 2d matrix from which points_i 
          and points_j are selected
    '''
    [jpj, jpi] = a_ji
    pnt_i = np.array(points_i)
    pnt_j = np.array(points_j)

    if (pnt_i[0] == pnt_i[-1]) and (pnt_i[0] == pnt_i[-1]):
        # polygon is already closed
        i_indx = np.copy(pnt_i)
        j_indx = np.copy(pnt_j)
    else:
        # close polygon
        i_indx = np.append( pnt_i, pnt_i[0])
        j_indx = np.append( pnt_j, pnt_j[0])

    [bound_j, bound_i] = get_poly_line_ij(i_indx, j_indx)

    mask = np.zeros(shape=(jpj,jpi))
    for n in range(len(bound_i)):
        i         = bound_i[n]
        j         = bound_j[n]
        mask[j,i] = 1
    corners_j = [ 0,   0, jpj, jpj ]
    corners_i = [ 0, jpi,   0, jpi ]

    for n in range(4):
        j = corners_j[n]
        i = corners_i[n]
        if mask[j,i] == 0:
           fill_i = i
           fill_j = j
           break

    mask_filled = floodfill(mask,fill_j,fill_i,1,1)
    for n in range(len(bound_i)):
        j                = bound_j[n]
        i                = bound_i[n]
        mask_filled[j,i] = 0

    # the points that are still 0 are within the required area
    [area_j, area_i] = np.where(mask_filled == 0);

    return area_j, area_i

# =====================================================================================================
def bresenham_line(x0, x1, y0, y1):
    '''
    point0 = (y0, x0), point1 = (y1, x1)

    It determines the points of an n-dimensional raster that should be 
    selected in order to form a close approximation to a straight line 
    between two points. Taken from the generalised algotihm on

    http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
    '''

    steep = abs(y1 - y0) > abs(x1 - x0)

    if steep:
       # swap(x0, y0)
       t  = y0
       y0 = x0
       x0 = t
       # swap(x1, y1)    
       t  = y1
       y1 = x1
       x1 = t

    if x0 > x1:
       # swap(x0, x1)
       t  = x1
       x1 = x0
       x0 = t
       # swap(y0, y1)
       t  = y1
       y1 = y0
       y0 = t

    deltax = np.fix(x1 - x0)
    deltay = np.fix(abs(y1 - y0))
    error  = 0.0

    deltaerr = deltay / deltax
    y = y0

    if y0 < y1:
       ystep = 1
    else:
       ystep = -1

    c=0
    pi = np.zeros(shape=[x1-x0+1])
    pj = np.zeros(shape=[x1-x0+1])
    for x in np.arange(x0,x1+1) :
        if steep:
           pi[c]=y
           pj[c]=x
        else:
           pi[c]=x
           pj[c]=y
        error = error + deltaerr
        if error >= 0.5:
           y = y + ystep
           error = error - 1.0
        c += 1

    return pj, pi

# =====================================================================================================

def filter_lat_lon(array, mesh, coords, new_val=0):
    """
    Filters the latitude and longitude values from the arguments.

    Parameters:
    array (xr.array): Input 4D array with depth values.
    input_data (xr.Dataset): Mesh data from the mesh file.
    coords (list): List of coordinates [LON_MIN, LON_MAX, LAT_MIN, LAT_MAX].

    Returns:
    xr.array: Masked array.
    """
    LON_MIN, LON_MAX, LAT_MIN, LAT_MAX = coords

    assert LON_MIN < LON_MAX, "LON_MIN must be less than LON_MAX"
    assert LAT_MIN < LAT_MAX, "LAT_MIN must be less than LAT_MAX"
    assert -90 <= LAT_MIN <= 90 and -90 <= LAT_MAX <= 90, "Latitude values must be between -90 and 90"
    assert -180 <= LON_MIN <= 180 and -180 <= LON_MAX <= 180, "Longitude values must be between -180 and 180"
    
    lat, lon = ('nav_lat', 'nav_lon') if 'nav_lat' in list(mesh.variables.keys()) else ('gphit', 'glamt')
    lat_grid = mesh[lat].values  # nj x ni array, latitudes of each grid point
    lon_grid = mesh[lon].values  # nj x ni array, longitudes of each grid point
        
    domain_mask = (lat_grid >= LAT_MIN) & (lat_grid <= LAT_MAX) & (lon_grid >= LON_MIN) & (lon_grid <= LON_MAX) # nj x ni array, boolean mask for a given domain
    
    return array.where(domain_mask, new_val)

def filter_depth(array, bathymetry, MAX_DEPTH, MIN_DEPTH=0, new_val=0):
    """
    Filters the depth values from the arguments.

    Parameters:
    array (xr.array): Input 4D array with depth values.
    input_data (xr.Dataset): Input data from the input file.
    depths (list): List of depth values to filter.

    Returns:
    xr.array: Masked array.
    """
    
    assert 0 <= MIN_DEPTH <= 6003, "Minimum depth value must be between 0 and 6003" 
    assert 0 <= MAX_DEPTH <= 6003, "Maximum depth value must be between 0 and 6003"
    assert MIN_DEPTH < MAX_DEPTH, "Minimum depth must be less than maximum depth"

    depth_mask = (bathymetry >= MIN_DEPTH) & (bathymetry <= MAX_DEPTH) # nj x ni array, boolean mask for a given depth range

    return array.where(depth_mask, new_val) 


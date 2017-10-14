# prodes2scidb
Scripts for loading PRODES and DETER data to SciDB



## Pre-requisites
- R language
- PRODES shapefiles of the classes deforestation and forest.
- SciDB and an array to hold the results (see notes below)
- PRODES  shapefiles *deforestation.shp* and *forest.shp*. These SHPs must have the following fields: 
    - MAINCLASS
    - CLASS_NAME
    - JULDAY
    - VIEW_DATE
    - ANO
- [DETER](http://www.obt.inpe.br/deter/dados/) shapefile called *deter_2014_2016.shp*. This SHP must have the following fields: 
    - CLASS_NAME
    - VIEW_DATE
    - JULDAY
    - ANO



## Files
- deter2scidb.sh                Bash script for loading DETER data to SciDB.
- getPixelCenters.R             R script. It returns a CSV of SciDB cell centers (WGS84 coordinates) given an interval of SciDB cells.
- getPixelCenters_wgs84.R       R script. It returns a CSV of SciDB cell centers (WGS84 coordinates) given an WGS84 bounding box.
- getPixelCenters_wgs84_shp.R   DEPRECATED. R script. It returns a shapefile of SciDB cell centers (WGS84 coordinates) given an WGS84 bounding box.
- LICENSE
- prodes2scidb.sh               Bash script for loading PRODES data to SciDB
- README.md                     This file.



## Instructions
1. Clone this project
2. Call prodes2scidb.sh using the parameters
    - lonmin        Minimum WGS84 longitude
    - lonmax        Maximum WGS84 longitude
    - latmin        Minimum WGS84 latitude
    - latmax        Maximum WGS84 latitude
    - defshp        Path to the PRODES deforestation SHP
    - forshp        Path to the PRODES forest SHP

The script prodes2scidb.sh does the following:
1 - Compute the SciDB cell centers falling inside the given WGS84 bounding box.
2 - Clip the deforestation and fores shapefiles using the given bounding box.
3 - Join the attributes of deforestation and forest to the cell centers
4 - Load the results to a SciDB array



## Notes
- The SciDB cell centers are computed from an array made to hold MODIS 250 meter data. i.e 
```
MOD13Q1 <ndvi:int16, evi:int16, quality:uint16, red:int16, nir:int16, blue:int16, mir:int16, view_zenith:int16, sun_zenith:int16, relative_azimuth:int16, day_of_year:int16, reliability:int8> [col_id=0:172799:0:40; row_id=0:86399:0:40; time_id=0:511:0:512]'
```

- The array to hold the PRODES results is created using this SciDB query
```
iquery -aq  "CREATE ARRAY DEFORESTATION <mainclass:string, class_name:string, yyyydoy:int32, view_date:string>[col_id=0:172799:0:40; row_id=0:86399:0:40]"
```

- The array to hold the DETER results is created using this SciDB query
```
iquery -aq  "CREATE ARRAY DEFORESTATION_DETER <class_name:string, yyyydoy:int32, view_date:string>[col_id=0:172799:0:40; row_id=0:86399:0:40]
```


## Examples

The scripts are called like this
```
./prodes2scidb.sh -61.8061 -61.16994 -8.110165 -7.628022 /home/scidb/alber/prodes2016/deforestation.shp /home/scidb/alber/prodes2016/forest.shp
./deter2scidb.sh  -61.8061 -61.16994 -8.110165 -7.628022 /home/scidb/alber/deter2016/deter_2014_2016.shp /home/scidb/alber/prodes2016/forest.shp
```


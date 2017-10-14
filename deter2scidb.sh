#!/bin/bash
################################################################################
# DETER TO SCIDB
#-------------------------------------------------------------------------------
# Rasterize DETER shapefiles to match SciDB MOD13Q1 array
#-------------------------------------------------------------------------------
# Example:
# ./deter2scidb.sh -61.8061 -61.16994 -8.110165 -7.628022 /home/scidb/alber/deter2016/deter_2014_2016.shp /home/scidb/alber/prodes2016/forest.shp
################################################################################


# validation
if [ "$#" -ne 6 ]; then
  echo "ERROR: wrong number of parameters! - 6 expected: lonmin lonmax latmin latmax deforestation_shp forest_shp " >&2
  exit 1
fi


# get parameters from the console
lonmin=$1
lonmax=$2
latmin=$3
latmax=$4
defshp=$5
forshp=$6
cdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# setup
#lonmin=-61.8061
#lonmax=-61.16994
#latmin=-8.110165
#latmax=-7.628022
#defshp=/home/alber/Documents/data/deter/deter_2014_2016.shp
#forshp=/home/alber/Documents/data/prodes2016/forest.shp
#cdir=/home/scidb/alber/prodes2scidb/test01
##defshp=/home/scidb/alber/deter2016/deter_2014_2016.shp
##forshp=/home/scidb/alber/prodes2016/forest.shp


echo "Getting MOD13Q1 pixel centers for a bounding box (WGS84)..."
Rscript getPixelCenters_wgs84.R lonmin=$lonmin lonmax=$lonmax latmin=$latmin latmax=$latmax output=modcellsR.csv
cut -d "," -f 2- modcellsR.csv > modcells.csv                                   # remove the CSV's first column
echo '<OGRVRTDataSource><OGRVRTLayer name="modcells"><SrcDataSource>modcells.csv</SrcDataSource><GeometryType>wkbPoint</GeometryType><LayerSRS>WGS84</LayerSRS><GeometryField encoding="PointFromColumns" x="x_wgs84" y="y_wgs84"/></OGRVRTLayer></OGRVRTDataSource>' > csv.vrt
ogr2ogr modcells.shp csv.vrt                                                    # export VRT to SHP


echo "Clipping shapefiles..."
parallel --eta --link ogr2ogr -f \"ESRI Shapefile\" {1} {2} -clipsrc $lonmin $latmin $lonmax $latmax ::: deforestation.shp forest.shp ::: $defshp $forshp


echo "Setting up the VRT files..."
echo '<OGRVRTDataSource><OGRVRTLayer name="deforestation"><SrcDataSource>deforestation.shp</SrcDataSource><SrcLayer>deforestation</SrcLayer></OGRVRTLayer><OGRVRTLayer name="modcells"><SrcDataSource>modcells.shp</SrcDataSource><SrcLayer>modcells</SrcLayer></OGRVRTLayer></OGRVRTDataSource>' > inputDef.vrt
echo '<OGRVRTDataSource><OGRVRTLayer name="forest">       <SrcDataSource>forest.shp</SrcDataSource>       <SrcLayer>forest</SrcLayer>       </OGRVRTLayer><OGRVRTLayer name="modcells"><SrcDataSource>modcells.shp</SrcDataSource><SrcLayer>modcells</SrcLayer></OGRVRTLayer></OGRVRTDataSource>' > inputFor.vrt


echo "Joining spatially..."
parallel --eta --link ogr2ogr -sql \"SELECT mc.col_id, mc.row_id, mc.geometry, df.CLASS_NAME, \(ANO \* 1000 \+ JULDAY\) as yyyydoy, df.VIEW_DATE from {1} df, modcells mc WHERE ST_INTERSECTS\(df.geometry, mc.geometry\)\" -dialect SQLITE {2} {3} ::: deforestation forest ::: mcJdef.shp mcJfor.shp ::: inputDef.vrt inputFor.vrt


echo "Exporting to a CSV..."
ogr2ogr -f CSV mcJdef.csv mcJdef.shp
ogr2ogr -f CSV mcJfor.csv mcJfor.shp


echo "Removing header on CSVs..."
sed -i '1d' mcJfor.csv
sed -i '1d' mcJdef.csv
#cat mcJfor.csv >> mcJdef.csv # NOTE: Do not join DETER and FOREST as they can overlap. The order on which they're loaded determines which one stays in SciDB


echo "Loading to SciDB..."
# NOTE: Generate the SciDB array
#iquery -aq "remove(DEFORESTATION_DETER)" 2> /dev/null; iquery -aq  "CREATE ARRAY DEFORESTATION_DETER <class_name:string, yyyydoy:int32, view_date:string>[col_id=0:172799:0:40; row_id=0:86399:0:40]"
# NOTE DETER can generate alerts for the same pixel twice the same year
# TODO: Write script to select the best observations (the first? the last?)
# 57068,46932,ALERTA,2015175.000000000000000,2015-06-24
# 57068,46932,ALERTA,2015319.000000000000000,2015-11-15
# WORKAROUND: XXX set redimension's isStrict to false. That way, SciDB handles cell collisions arbitrarily
iquery -naq "insert(redimension(cast(input(<col_id:int64, row_id:int64, class_name:string, yyyydoy:double, view_date:string>[i=0:*,?,0], '$cdir/mcJdef.csv', -2, 'CSV'), <col_id:int64, row_id:int64, class_name:string, yyyydoy:int32, view_date:string>[i=0:*,?,0]), DEFORESTATION_DETER, false), DEFORESTATION_DETER)"
iquery -naq "insert(redimension(cast(input(<col_id:int64, row_id:int64, class_name:string, yyyydoy:double, view_date:string>[i=0:*,?,0], '$cdir/mcJfor.csv', -2, 'CSV'), <col_id:int64, row_id:int64, class_name:string, yyyydoy:int32, view_date:string>[i=0:*,?,0]), DEFORESTATION_DETER), DEFORESTATION_DETER)"


#echo "Cleaning..."
echo "Finished!"


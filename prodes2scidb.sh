#!/bin/bash
################################################################################
# PRODES TO SCIDB
#-------------------------------------------------------------------------------
# Rasterize PRODES-DETER shapefiles to match SciDB MOD13Q1 array
#-------------------------------------------------------------------------------
# Example:
# ./prodes2scidb.sh -61.8061 -61.16994 -8.110165 -7.628022 /home/scidb/alber/prodes2016/deforestation.shp /home/scidb/alber/prodes2016/forest.shp
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
#defshp=/home/alber/Documents/data/prodes2016/deforestation.shp
#forshp=/home/alber/Documents/data/prodes2016/forest.shp
#cdir=/home/scidb/alber/prodes2scidb/test01
##defshp=/home/scidb/alber/prodes2016/deforestation.shp
##forshp=/home/scidb/alber/prodes2016/forest.shp

echo "Getting MOD13Q1 pixel centers for a bounding box (WGS84)..."
Rscript getPixelCenters_wgs84.R lonmin=$lonmin lonmax=$lonmax latmin=$latmin latmax=$latmax output=modcellsR.csv
cut -d "," -f 2- modcellsR.csv > modcells.csv                                   # remove the CSV's first column
echo '<OGRVRTDataSource><OGRVRTLayer name="modcells"><SrcDataSource>modcells.csv</SrcDataSource><GeometryType>wkbPoint</GeometryType><LayerSRS>WGS84</LayerSRS><GeometryField encoding="PointFromColumns" x="x_wgs84" y="y_wgs84"/></OGRVRTLayer></OGRVRTDataSource>' > csv.vrt
ogr2ogr modcells.shp csv.vrt                                                    # export VRT to SHP

echo "Clipping shapefiles..."
parallel --eta --link ogr2ogr -f \"ESRI Shapefile\" {1} {2} -clipsrc $lonmin $latmin $lonmax $latmax ::: deforestation.shp forest.shp ::: $defshp $forshp
# No GNU PARALLEL
# ogr2ogr -f "ESRI Shapefile" deforestation.shp $defshp -clipsrc $lonmin $latmin $lonmax $latmax
# ogr2ogr -f "ESRI Shapefile" forest.shp        $forshp -clipsrc $lonmin $latmin $lonmax $latmax

echo "Setting up the VRT files..."
echo '<OGRVRTDataSource><OGRVRTLayer name="deforestation"><SrcDataSource>deforestation.shp</SrcDataSource><SrcLayer>deforestation</SrcLayer></OGRVRTLayer><OGRVRTLayer name="modcells"><SrcDataSource>modcells.shp</SrcDataSource><SrcLayer>modcells</SrcLayer></OGRVRTLayer></OGRVRTDataSource>' > inputDef.vrt
echo '<OGRVRTDataSource><OGRVRTLayer name="forest">       <SrcDataSource>forest.shp</SrcDataSource>       <SrcLayer>forest</SrcLayer>       </OGRVRTLayer><OGRVRTLayer name="modcells"><SrcDataSource>modcells.shp</SrcDataSource><SrcLayer>modcells</SrcLayer></OGRVRTLayer></OGRVRTDataSource>' > inputFor.vrt

echo "Joining spatially..."
parallel --eta --link ogr2ogr -sql \"SELECT mc.col_id, mc.row_id, mc.geometry, df.MAINCLASS, df.CLASS_NAME, \(ANO \* 1000 \+ JULDAY\) as yyyydoy, df.VIEW_DATE from {1} df, modcells mc WHERE ST_INTERSECTS\(df.geometry, mc.geometry\)\" -dialect SQLITE {2} {3} ::: deforestation forest ::: mcJdef.shp mcJfor.shp ::: inputDef.vrt inputFor.vrt
# No GNU PARALLEL
#ogr2ogr -sql "SELECT mc.col_id, mc.row_id, mc.geometry, df.MAINCLASS, df.CLASS_NAME, (ANO * 1000 + JULDAY) as yyyydoy, df.VIEW_DATE from deforestation df, modcells mc WHERE ST_INTERSECTS(df.geometry, mc.geometry)" -dialect SQLITE mcJdef.shp inputDef.vrt
#ogr2ogr -sql "SELECT mc.col_id, mc.row_id, mc.geometry, df.MAINCLASS, df.CLASS_NAME, (ANO * 1000 + JULDAY) as yyyydoy, df.VIEW_DATE from forest df, modcells mc WHERE ST_INTERSECTS(df.geometry, mc.geometry)" -dialect SQLITE mcJfor.shp inputFor.vrt

echo "Exporting to a CSV..."
ogr2ogr -f CSV mcJdef.csv mcJdef.shp
ogr2ogr -f CSV mcJfor.csv mcJfor.shp

echo "Joining CSVs..."
sed -i '1d' mcJfor.csv
sed -i '1d' mcJdef.csv
cat mcJfor.csv >> mcJdef.csv

echo "Loading to SciDB..."
#iquery -aq "remove(DEFORESTATION)" 2> /dev/null; iquery -aq  "CREATE ARRAY DEFORESTATION <mainclass:string, class_name:string, yyyydoy:int32, view_date:string>[col_id=0:172799:0:40; row_id=0:86399:0:40]"
iquery -naq "insert(redimension(cast(input(<col_id:int64, row_id:int64, mainclass:string, class_name:string, yyyydoy:double, view_date:string>[i=0:*,?,0], '$cdir/mcJdef.csv', -2, 'CSV'), <col_id:int64, row_id:int64, mainclass:string, class_name:string, yyyydoy:int32, view_date:string>[i=0:*,?,0]), DEFORESTATION), DEFORESTATION)"

echo "Cleaning..."



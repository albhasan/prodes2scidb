################################################################################
# GET SCIDB CELL CENTERS IN FROM A WGS84 BOUNDING BOX
# Given a bounding box in WGS84 coordinates, get the SciDB cells centers 
# (MOD13Q1) as a CSV
# centers and then saves the result as CSV
#---- Notes ----
# - DEPRECATED: rgdal::writeOGR throws an error on the server when called using Rscript but not when executed line by line
#---- Usage ----
# Rscript getPixelCenters_wgs84_shp.R lonmin=-61.8061 lonmax=-61.16994 latmin=-8.110165 latmax=-7.628022 output=deleteme
################################################################################
stop("WARNING: Do not use this script. rgdal::writeOGR throws errors using Rscript")
#---- get parameters from command line ----
lonmin <- NA
lonmax <- NA
latmin <- NA
latmax <- NA
output <- NA                                                                    # file path to the file where to store the results
argsep <- "="                                                                   # separator between the argument name and its value during invocation i.e. arg=value
keys <- vector(mode = "character", length = 0)
values <- vector(mode = "character", length = 0)
for (arg in commandArgs()){
  if(agrep(argsep, arg) == TRUE){
    pair <- unlist(strsplit(arg, argsep))
    keys <- append(keys, pair[1], after = length(pair))
    values <- append(values, pair[2], after = length(pair))
  }
}   
lonmin <- as.numeric(unlist(strsplit(values[which(keys == "lonmin")], ",")))
lonmax <- as.numeric(unlist(strsplit(values[which(keys == "lonmax")], ",")))
latmin <- as.numeric(unlist(strsplit(values[which(keys == "latmin")], ",")))
latmax <- as.numeric(unlist(strsplit(values[which(keys == "latmax")], ",")))
output <- unlist(strsplit(values[which(keys == "output")], ","))
if(is.null(output)){
  output <- "output.csv" 
}else{
  output <- unlist(strsplit(values[which(keys == "output")], ","))
}
if(is.na(lonmin) || is.na(lonmax) || is.na(latmin) || is.na(latmax)){
  stop("Invalid parameters!")
}
#---- get bbox as crids ----
bbox <- matrix(c(lonmin, lonmax, latmin, latmax), ncol = 2)
crids.bb <- scidbutil::wgs84gmpi(lonlat.mat = bbox, 
  pixelSize = scidbutil::calcPixelSize(4800, scidbutil::calcTileWidth()))
#---- build the cell centers ----
col_id <- seq(from  = crids.bb[1, 1], to = crids.bb[2, 1])
row_id <- seq(from  = crids.bb[1, 2], to = crids.bb[2, 2])
crids <- as.matrix(expand.grid(col_id, row_id))
colnames(crids) <- c("col_id", "row_id")
ps <- scidbutil::calcPixelSize(4800, scidbutil::calcTileWidth())
pixs <- scidbutil::getxyMatrix(colrowid.Matrix = crids, pixelSize = ps)
#---- project from sinusoidal to wgs84 ----
proj_modis_sinusoidal <- "+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs"
proj4326 <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
S <- sp::SpatialPoints(pixs)
sp::proj4string(S) <- sp::CRS(proj_modis_sinusoidal)
points.sp <- sp::spTransform(S, sp::CRS(proj4326))
pixs <- as.data.frame(cbind(pixs, crids))
rownames(pixs) <- NULL
colnames(pixs) <- c('x_wgs84', 'y_wgs84', 'col_id', 'row_id')
points.spdf <- sp::SpatialPointsDataFrame(coords = points.sp, data = pixs)
#---- save ----
rgdal::writeOGR(points.spdf, dsn = dirname(output), layer = basename(output), driver = "ESRI Shapefile")

################################################################################
# GET SCIDB CELL CENTERS IN WGS84 AS CSV
# Given a bounding box of SciDB cells (MOD13Q1), this script computes the 
# centers and then saves the result as CSV
#---- Usage ----
# Rscript getPixelCenters.R cid_from=57084 cid_to=57104 rid_from=46857 rid_to=46881 output=/home/alber/Desktop/deleteme.csv
################################################################################
#---- get parameters from command line ----
cid_from <- NA                                                                  # col_id
cid_to <- NA
rid_from <- NA                                                                  # row_id
rid_to <- NA
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
cid_from <- as.numeric(unlist(strsplit(values[which(keys == "cid_from")], ",")))
cid_to <-   as.numeric(unlist(strsplit(values[which(keys == "cid_to")], ",")))
rid_from <- as.numeric(unlist(strsplit(values[which(keys == "rid_from")], ",")))
rid_to <-   as.numeric(unlist(strsplit(values[which(keys == "rid_to")], ",")))
output <- unlist(strsplit(values[which(keys == "output")], ","))
if(is.null(output)){
  output <- "output.csv" 
}else{
  output <- unlist(strsplit(values[which(keys == "output")], ","))
}
if(is.na(cid_from) || is.na(cid_to) || is.na(rid_from) || is.na(rid_to)){
  stop("Invalid parameters!")
}
#---- build the cell centers ----
col_id <- seq(from  = cid_from, to = cid_to)
row_id <- seq(from  = rid_from, to = rid_to)
crids <- as.matrix(expand.grid(col_id, row_id))
names(crids) <- c("col_id", "row_id")
ps <- scidbutil::calcPixelSize(4800, scidbutil::calcTileWidth())
pixs <- scidbutil::getxyMatrix(colrowid.Matrix = crids, pixelSize = ps)
#---- project from sinusoidal to wgs84 ----
proj_modis_sinusoidal <- "+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs"
proj4326 <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"
S <- sp::SpatialPoints(pixs)
sp::proj4string(S) <- sp::CRS(proj_modis_sinusoidal)
pixs <- sp::spTransform(S, sp::CRS(proj4326))@coords
pixs <- cbind(pixs, crids)
rownames(pixs) <- NULL
colnames(pixs) <- c('x_wgs84', 'y_wgs84', 'col_id', 'row_id')
#---- save ----
write.csv(pixs, file = output)

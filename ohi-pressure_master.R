
#
key <- "pressure"

###############################################################################
#### Setup file structure
###############################################################################
dir.main <- file.path(paste0(letters, ":"),
  file.path("ohi"))
dir.main <- dir.main[file.exists(dir.main)]
if (length(dir.main) > 1) stop(length(dir.main),
  " ohi/ directories were found.")
dir.pressure <- file.path(dir.main, "ohi-pressure")
dir.data <- file.path(dir.pressure, "data")

setwd(dir.main)
dir.create(dir.pressure, showWarnings = FALSE)
dir.create(dir.data, showWarnings = FALSE)

# Create a folder for temporary files, these files are written to the disk
# when there is not enough storage in the memory to keep them. The folder will
# be used by rater functions.
dir.temp <- file.path(dir.data, "temp")
dir.create(dir.temp, showWarnings = FALSE)
raster::rasterOptions(tmpdir = dir.temp)

###############################################################################
#### Download the necessary github folders and files
###############################################################################
system("git clone https://github.com/kellijohnson/ftp_data.git")
system("git clone https://github.com/kellijohnson/ohicore.git")
system("git clone https://github.com/kellijohnson/ohi-global.git")
system("git clone https://github.com/kellijohnson/ohiprep.git")
system("git clone https://github.com/kellijohnson/ohi_global_sim.git")

# Download necessary files
temp <- tempfile()

download.file("https://ohi.nceas.ucsb.edu/data/data/regions.zip", temp)
unzip(temp, exdir = dir.data)
download.file(
  "https://ohi.nceas.ucsb.edu/data/data/spatial_ohi_supplement.zip", temp)
unzip(temp, exdir = dir.data)
unzip(temp, exdir = dir.data)
# OA data
# download.file(
#   "https://ohi.nceas.ucsb.edu/data/data/acid.zip", temp)
# unzip(temp, exdir = dir.data)

download.file("https://raw.githubusercontent.com/OHI-Science/ohiprep/master/globalprep/spatial/v2013/rgn_labels.csv", temp)
get_rgn_names <- read.table(temp, sep = ",", header = TRUE)[, c(1, 3)]
colnames(get_rgn_names)[2] <- "rgn_name"

unlink(temp)

###############################################################################
#### Libraries
###############################################################################
devtools::install_github("oharac/provRmd")
devtools::install_github("ohi-science/ohicore@master")
devtools::install_github("ohi-science/ohirepos")
devtools::install_github("ropensci/git2r")

library(devtools)
library(doParallel)
library(dplyr)
library(foreach)
library(geojsonio)
library(ggplot2)
library(git2r) 
library(knitr)
library(lattice)
library(maptools)
library(ncdf4)
library(ohicore)
library(ohirepos)
library(pander)
library(parallel)
library(plotly)
library(provRmd)
library(psych)
library(raster)
library(rasterVis)
library(RColorBrewer)
library(RCurl)
library(rgdal)
library(rmapshaper)
library(root)
library(R.utils)
library(shapefiles)
library(sp)
library(stringr)
library(tidyr)
library(tidyverse)
library(tmap)
library(truncnorm)

# Set up repo as a ohi repository
# todo: fix the ohi repository

# repo_registry <- readr::read_csv("repo_registry.csv") %>%
#   dplyr::filter(study_key == key) %>%
#   dplyr::mutate(dir_repo = file.path(dir.main, key))

###############################################################################
#### Shapefiles
###############################################################################
mollCRS <- crs("+proj=moll +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs")
p4s_wgs84 <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

cols <- rev(colorRampPalette(brewer.pal(9, "Spectral"))(255))
ocean <- raster(file.path(dir.data, "ocean.tif"))
ocean_shp <- rgdal::readOGR(file.path(dir.data), layer = "regions_gcs")
land <- ocean_shp %>%
  subset(rgn_typ %in% c("land", "land-disputed", "land-noeez"))


###############################################################################
#### Cluster
###############################################################################
cl <- makePSOCKcluster(10)
registerDoParallel(cl)

###############################################################################
#### Code
###############################################################################
source(file.path(dir.pressure, "ohi-pressure_oa.R"))

###############################################################################
#### End
###############################################################################
stopCluster(cl)
unlink(dir.temp, recursive = TRUE)

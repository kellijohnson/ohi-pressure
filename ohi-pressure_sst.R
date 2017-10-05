# Selig, E.R., K.S. Casey, and J.F. Bruno. 2010. New insights into global patterns of ocean temperature anomalies: implications for coral reef health and management. Global Ecology and Biogeography, DOI: 10.1111/j.1466-8238.2009.00522.x.
# https://cdn.rawgit.com/OHI-Science/ohiprep/master/globalprep/prs_sst/v2016/sst_layer_prep.html

# #Methods
# 1. Extreme events per year based calculated as number of times SST anomaly
# exceeds SST Standard Deviation based on weekly values
# (annual_pos_anomalies data, see v2015/dataprep.R for analysis).
# 2. Sum extreme events for five year periods to control for yearly variation.
# 3. Change in extreme events: Subtract number of extreme events for each
# five-year period from control period (1985-1989).
# 4. Rescale "Change in extreme events" data to values between 0 and 1 by
# dividing by the 99.99th quantile among all years of data.

# **Format**: NetCDF
# **Native Data Resolution**: 4km
# Data was obtained from nodc.noaa.gov/sog/cortad V5
# doi:10.7289/V5CZ3545
# Three dimensions (time, latitude, and longitude), where the
# dimensions are c(1617, 4320, 8640) and time is the middle of the week.
# One entry for every week since 1982-01-02
# Cortadv5_SSTA.nc = SST anomalies
# (weekly SST minus weekly climatological SST),
# weekly data for all years, degrees Kelvin
# Cortadv5_weeklySST.nc =  SST, weekly data for all years, degrees Kelvin
# **Time Range**: 1982 - 2012 (weekly averages across all years)

###############################################################################
#### Prep raw sea surface temperature (CoRTAD version 5) for OHI 2015
###############################################################################
file_sst <- file.path(dir.data, "cortadv5_WeeklySST.nc")
file_ssta <- file.path(dir.data, "cortadv5_SSTA.nc")

ssta         <- stack(file_ssta, varname = "SSTA")
weekly_sst   <- stack(file_sst, varname = "WeeklySST")
names_ssta   <- names(ssta)
names_weekly <- names(weekly_sst)

#Create weekly standard deviations across all years
foreach(i = 1:53) %dopar% {
  s <- stack()
  for (j in 1982:2012) {
    w <- which(substr(names_weekly, 2, 5) == j)[i]
    if(is.na(w)) next()
    w_week <- weekly_sst[[w]]
    s <- stack(s, w_week)
  }
  sd <- calc(s, fun = function(x){sd(x, na.rm = TRUE)},
    progress = "text", 
    filename = file.path(dir.data, paste0("sd_sst_week_", i,".tif")))
  rm(s, sd)
}

# Calculate annual positive anomalies
foreach(i = 1982:2012) %dopar% {
  s <- stack()
  for (j in 1:53) {
    sd <- raster(file.path(dir.data, paste0("sd_sst_week_",j,".tif"))) #sd for week
    w <- which(substr(names_ssta, 2, 5) == i)[j]
    if(is.na(w)) next()
    # subset the week/year anomaly
    w_ssta <- ssta[[w]]
    # compare to average anomaly for that week
    count <- overlay(w_ssta,sd, fun = function(x,y){ifelse(x>y, 1, 0)},
      progress = "text")
    s <- stack(s,count)
  }
  year <- calc(s, fun = function(x){sum(x, na.rm = TRUE)},
    progress = "text",
    filename = file.path(dir.temp, paste0("annual_pos_anomalies_sd_", i, ".tif")),
    overwrite = TRUE)
  rm(s, year)
}

###############################################################################
#### 5-year averages and differences from the mean
###############################################################################
l <- list.files(dir.temp,
  pattern = "annual_pos_anomalies", full.names = TRUE)
lyrs <- as.numeric(sapply(lapply(strsplit(l, "_|\\."), tail, 2), "[[", 1))

# Get 5 year aggregates
  # 5-year historical comparison
  ref <- stack(l[4:8]) %>% sum(.)

foreach(i = 1986:2008, .packages = c("dplyr", "raster")) %dopar% {
  yrs <- c(i:(i+4))
  s <- raster::stack(l[lyrs%in%yrs])
  #calc diff between recent 5 year mean and ref
  diff <- raster::overlay(s, ref,
    fun = function(x,y){x-y}) %>% mask(land, inverse = TRUE)
  writeRaster(diff,
    filename = file.path(dir.data,
      paste0("sst_diff_ocean_", yrs[1], "-", yrs[5],".tif")),
      overwrite = TRUE)
  rm(diff, s)
}

###############################################################################
#### 99.99th quantile across all difference rasters
###############################################################################
diffs <- list.files(dir.data, pattern = "diff", full.names = TRUE)
# get data across all years
vals <- c()

for(i in 1:length(diffs)){
  m <- diffs[i] %>%
    raster() %>%
    getValues()
  vals <- c(vals, m)
}
min_v <- min(vals, na.rm = TRUE)
max_v <- max(vals, na.rm = TRUE)
resc_num <- quantile(vals, prob = 0.9999, na.rm = TRUE)
sprintf("Rescaling")

foreach(i = 1:length(diffs)) %dopar% {
  r <- raster(diffs[i])
  yrs <- as.numeric(gsub("\\.tif", "", strsplit(diffs[i], "[[:digit:]]{4}-")[[1]][2]))
  projection(r) <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"
  out <- projectRaster(r, crs = mollCRS, over = TRUE) %>%
    calc(.,
      fun = function(x){ifelse(x > 0,
        ifelse(x > resc_num, 1, x / resc_num), 0)}) %>%
        raster::resample(., ocean, method = "ngb",
          filename = file.path(dir.data,
            paste0("sst_", yrs, "_1985-1989.tif")),
          overwrite = TRUE)
  rm(out)
}

res <- list.files(dir.data, pattern = "_1985-1989.tif", full.names = TRUE)

plot(raster(res[23]), col = cols, axes = FALSE,
  main = "Sea Surface Temperature Pressure Layer \n OHI 2016")

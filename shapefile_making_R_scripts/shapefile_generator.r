
if(FALSE) { # create country centroid shapefile 

library(sp)
library(rgdal)
library(rgeos)
library(dplyr)
library(sf)

points_df = CoordinateCleaner::countryref %>% # centroids from the CoordinateCleaner package
filter(type == "country") %>% # only country centroids
filter(area_sqkm >= 10e3) %>% # only with land area greater than 10km2
select(iso2,long=centroid.lon,lat=centroid.lat) %>%
mutate(ID = row_number()) %>%
glimpse() 

points_sp = SpatialPointsDataFrame(points_df[, c("long", "lat")], data.frame(ID=seq(1:nrow(points_df))), proj4string=CRS("+proj=longlat +ellps=WGS84 +datum=WGS84"))

aeqd.buffer = function(p, r) {
stopifnot(length(p) == 1)
aeqd = sprintf("+proj=aeqd +lat_0=%s +lon_0=%s +x_0=0 +y_0=0", p@coords[[2]], p@coords[[1]])
projected = spTransform(p, CRS(aeqd))
buffered = gBuffer(projected, width=r, byid=TRUE)
spTransform(buffered, p@proj4string)
}

polygon_list = list()
for(i in 1:nrow(points_sp)) { 
polygon_list[[i]] = aeqd.buffer(points_sp[i,], 2000) %>% # two kilometer buffer around point 
sf::st_as_sf()
}

sf_obj = polygon_list %>% 
do.call("rbind",.) %>%
merge(points_df,id="ID") %>%
select(ID,iso2,geometry)

# wicket::sp_convert() 
sf_obj

st_write(sf_obj, "C:/Users/ftw712/Desktop/country_centroid_shapefile/country_centroid_shapefile.shp")

# scp -r /cygdrive/c/Users/ftw712/Desktop/country_centroid_shapefile/ jwaller@c4gateway-vh.gbif.org:/home/jwaller/
# hdfs dfs -put country_centroid_shapefile/ country_centroid_shapefile
# hdfs dfs -ls 

}

if(FALSE) { # isea3h grid processing 
library(roperators)
library(dplyr)
library(dggridR) # used to make hexagon grid
library(sf)
library(purrr)

load("C:/Users/ftw712/Desktop/isea3h.rda")

isea3h = isea3h %>%
filter(res == 4) %>% # actually resolution 5 since this data is indexed at 0
filter(centroid == 0) %>%  
glimpse()

polygon_list = isea3h %>%
group_split(id) %>%
map(~ .x %>%
select(lon,lat) %>%
as.matrix() %>% 
list() %>%
st_polygon() %>% 
st_wrap_dateline(options = c("WRAPDATELINE=YES"))  
) 

polygon_list 

# split multipolygons into polygons
sf_obj = st_set_geometry(data.frame(unique(isea3h$id)),st_cast(st_sfc(polygon_list), "MULTIPOLYGON")) %>% 
st_cast("POLYGON") %>%
st_set_crs(4326)

polygon = sf_obj %>% filter(unique.isea3h.id. == "571") 
polygon$geometry[[1]]

# st_write(sf_obj, "C:/Users/ftw712/Desktop/isea3h_res5_shapefile/isea3h_res5_shapefile.shp")

# st_write(sf_obj, "C:/Users/ftw712/Desktop/isea3h_res5_shapefile/isea3h_res5_shapefile.shp")
# st_write(sf_obj, "C:/Users/ftw712/Desktop/polygon_grid_shapefile/polygon.shp")

# scp -r /cygdrive/c/Users/ftw712/Desktop/isea3h_res5_shapefile/ jwaller@c4gateway-vh.gbif.org:/home/jwaller/
# hdfs dfs -put isea3h_res5_shapefile/ isea3h_res5_shapefile
# hdfs dfs -ls 

}

if(FALSE) { # make polygon grid shapefile 

library(roperators)
library(dplyr)
library(dggridR) # used to make hexagon grid
library(sf)
library(purrr)
# library(magrittr) # for %T>% pipe

# taxonKey = "789"
# spacing = 300 # space between hexagon grids in miles I think 
# facet = "speciesKey" # which rank to use... # can also be genusKey

# grid = dggridR::dgconstruct(spacing=spacing, metric=FALSE, resround='down') %>%
# gbifrasters::getPolygonGrid(spacing,landOnly=TRUE) %>%
# saveRDS(file="C:/Users/ftw712/Desktop/grid.rda")

# st_polygon(list(polygon_matrix))
grid = readRDS(file="C:/Users/ftw712/Desktop/grid.rda")


polygon_list = grid %>%
filter(cell == "246") %>%
group_split(cell) %>%
map(~ .x %>%
select(long,lat) %>%
as.matrix() %>% 
list() %>%
st_polygon()
)

polygon_list

g = st_sfc(polygon_list)
sf_obj = st_sf(cell = unique(grid$cell),g,crs = 4326) # final sf object 


# st_write(sf_obj, "C:/Users/ftw712/Desktop/polygon_grid_shapefile/polygon.shp")
}

if(FALSE) { # make ashe shapefile 
library(sf)
library(dplyr)

fname = system.file("shape/nc.shp", package="sf")
nc = st_read(fname)

ashe = nc %>% 
filter(NAME == "Ashe") %>%
st_cast("POLYGON")

ashe = rbind(ashe,ashe,ashe)
ashe %>% class()

st_write(ashe, "C:/Users/ftw712/Desktop/ashe/ashe.shp")
}





if(FALSE) { # get centroid data from Geolocate

# q=paste("http://geo-locate.org/webservices/geolocatesvcv2/glcwrap.aspx?country=",Country,"&locality=",Locality,"&state=",StateProvince,"&county=",County,OPTIONS, sep='')
# ,"&locality=",Locality,"&state=",StateProvince,"&county=",County,OPTIONS, sep='')

library(httr)
library(dplyr)
library(roperators)
library(purrr)

# Test Query 
# Country = "China"
# Locality = "China"
# base_url = "http://geo-locate.org/webservices/geolocatesvcv2/glcwrap.aspx?"
# query = base_url %+% "country=" %+% Country %+% "&locality=" %+% Locality


d = countrycode::codelist %>% 
select(
iso2c,
iso3c,
genc.name,
iso.name.en,
cldr.short.en,
cldr.variant.en,
country.name.en) %>% 
tidyr::pivot_longer(cols = 
c(genc.name,
iso.name.en,
cldr.short.en,
cldr.variant.en,
country.name.en)) %>%  
select(iso2c,iso3c,value) %>%
filter(!grepl("&",value)) %>% # remove those with amperstand 
unique() %>%
na.omit() %>%
glimpse() 

# country_variants = d$value %>% 
# unique() 

# base_url = "http://geo-locate.org/webservices/geolocatesvcv2/glcwrap.aspx?"
# querys = base_url %+% "country=" %+% country_variants %+% "&locality=" %+% country_variants

# querys %>%
# map( ~
# httr::GET(.x) %>% httr::content()
# ) %>% 
# saveRDS("C:/Users/ftw712/Desktop/query.rda")


L = readRDS("C:/Users/ftw712/Desktop/query.rda") %>%
map(~ .x %>%
pluck("resultSet") %>%
pluck("features")
)

parsePattern = L %>% 
map(~ .x %>% 
map(~ .x$properties) %>% 
map_chr(~ .x$parsePattern)
) %>% 
purrr::map_if(is_empty, ~ NA_character_)

uncertaintyRadiusMeters = L %>% 
map(~ .x %>% 
map(~ .x$properties) %>% 
map_chr(~ .x$uncertaintyRadiusMeters)
) %>% 
purrr::map_if(is_empty, ~ NA_character_)

coordinates = L %>% 
map(~ .x %>%
map(~ .x$geometry) %>%
map(~ .x$coordinates) 
) 

lon = coordinates %>% 
map(~ .x %>% map_chr(~ .x[[1]])) %>%
purrr::map_if(is_empty, ~ NA_character_)  

lat = coordinates %>% 
map(~ .x %>% map_chr(~ .x[[2]])) %>%
purrr::map_if(is_empty, ~ NA_character_) 

centroids = tibble(parsePattern,lat,lon,uncertaintyRadiusMeters) %>%
tidyr::unnest() %>%
unique() %>% 
na.omit() %>%
filter(uncertaintyRadiusMeters == "301") %>% 
mutate(value = parsePattern) %>%
merge(d,id=value,all.x=TRUE) %>%
mutate(lat = as.numeric(lat)) %>% 
mutate(lon = as.numeric(lon)) %>%
mutate(source = "http://geo-locate.org") %>% 
na.omit() %>%
saveRDS("C:/Users/ftw712/Desktop/gbif_shapefile_geocoder/shapefile_making_R_scripts/data/geolocate_centroids.rda") %>% 
glimpse() 

}

if(FALSE) { # create centroids.rda 

library(dplyr)
library(purrr)

geolocate_centroids = readRDS("C:/Users/ftw712/Desktop/gbif_shapefile_geocoder/shapefile_making_R_scripts/data/geolocate_centroids.rda") %>% 
mutate(iso2 = iso2c) %>% 
mutate(iso3 = iso3c) %>% 
select(iso2,iso3,lon,lat,source) %>%
glimpse() 

# filter(area_sqkm >= 10e3) %>% # only with land area greater than 10km2
# mutate(ID = row_number()) %>%

cc_centroids = CoordinateCleaner::countryref %>% # centroids from the CoordinateCleaner package
filter(type == "country") %>% # only country centroids
select(iso2,iso3,lon=centroid.lon,lat=centroid.lat) %>%
mutate(source = "CoordinateCleaner") %>%
glimpse() 

centroids = rbind(geolocate_centroids,cc_centroids) %>% 
merge(gbifapi::get_gbif_countries(),id="iso3",all.x=TRUE) %>% 
na.omit() %>% 
glimpse()

land_area_km2 = centroids %>%
pull(iso2) %>%
unique() %>%
wbstats::wb(country = ., 
indicator = c("AG.LND.TOTL.K2"),
startdate = 2018, enddate = 2019) %>% 
select(iso2 = iso2c,area_km2 = value)

centroids = merge(centroids,land_area_km2,id="iso2",all.x=TRUE) %>%
glimpse() %>%
select(iso2,iso3,lon,lat,centroid_source=source,country_name=title,area_km2) %>%
saveRDS("C:/Users/ftw712/Desktop/gbif_shapefile_geocoder/shapefile_making_R_scripts/data/centroids.rda") 

}

if(FALSE) { # plot centroids 

map_centroids = function(
centroids,
focal_iso = "AFG",
save_path = "C:/Users/ftw712/Desktop/gbif_shapefile_geocoder/shapefile_making_R_scripts/plots/centroids/"
) {

library(tmap)
data("World")

centroids = centroids %>% 
filter(iso3==!!focal_iso)

shape = sf::st_as_sf(centroids, coords = c("lon", "lat"), crs = 4326) %>%
glimpse() 

World = World %>%  
filter(iso_a3==!!focal_iso) %>%
mutate(iso_a3 = forcats::fct_drop(iso_a3)) %>%
glimpse()

if(nrow(World) > 0 && nrow(shape) > 0) {

tm = tm_shape(World) +
tm_layout(title=unique(centroids$title)) +
tm_polygons("iso_a3",palette = "gray") +
tm_legend(show=FALSE) +
tm_shape(shape) +
tm_dots(col = "source",palette=c(`http://geo-locate.org`='cyan', `CoordinateCleaner`='yellow'),size = 0.3,shape =21) +
tm_legend(show=TRUE) 

# tmap_options(max.categories = 177) +
# tmap_options(limits = c(facets.plot = 177)) + 
# tm_facets("iso_a3") +
# return(tm)

tmap_save(tm,filename=paste0(save_path,"centroids_",focal_iso,".pdf"),height=9,width=16,units="cm")
}

}

library(tmap)
data("World")

World %>%
filter(!iso_a3 == "FJI") %>% 
pull(iso_a3) %>%
unique() %>%
map(~ map_centroids(centroids,focal_iso=.x))

}

if(FALSE) { # plot centroids with ggplot2
# centroids


library(tmap)
library(ggplot2)
data("World")

# World = World %>% 
# select(iso_a3,name) 
# glimpse() 

# sf::st_crs(World)

# 5310471/100000

countries = ggspatial::df_spatial(World) %>%
mutate(order_id = row_number()) %>%
mutate(x = x/100000) %>%
mutate(y = y/100000) %>% 
glimpse()
# merge(centroids,id="iso_a3",all.x=TRUE) %>% 
# arrange(-order_id) %>%

countries = map_data("world") %>% glimpse()

# countries
# geom_polygon(data=countries,aes(x, y, group=piece_id), fill="#D8DACF",alpha=0.8) +

# p = ggplot() +
p = ggplot() +
geom_polygon(data=countries,aes(x=long, y=lat, group=group), fill="#D8DACF",alpha=0.8) +
geom_point(data=centroids,aes(lon,lat),color="red") 

# +
# facet_wrap(~ group,scales="free",ncol=1) 
# coord_cartesian() 

# +

# + 
# geom_point(data=centroids,aes(lon,lat)) 

# ggsave("C:/Users/ftw712/Desktop/plot.pdf",plot=p,width=5,height=500,limitsize=FALSE)
ggsave("C:/Users/ftw712/Desktop/plot.pdf",plot=p,width=16,height=9,limitsize=FALSE)
# countries = map_data("world")



# countries %>% glimpse()

# geom_sf() + 
# coord_sf() + 
# facet_grid(iso_a3~.)



# fortify() %>%
# class()

# %>%
# mutate(iso_a3 = iso3c) 


# %>% 
# filter(iso3c == "SWE")

# centroids$iso3c %>% unique()
# filter(iso_a3 == "SWE") %>%  

# library(tmap)
# data("World")

# shape = sf::st_as_sf(centroids, coords = c("lon", "lat"), crs = 4326) %>%
# as.data.frame() %>%
# glimpse()

# shape %>% glimpse()
# mutate(iso_a3 = forcats::fct_drop(iso_a3)) %>% 

# World = World %>% 
# as.data.frame() %>%
# merge(shape,id="iso_a3",all.x=TRUE) %>%
# glimpse()


# tm_shape(shape) + tm_dots() 
# shape

# tm = tm_shape(World) +
# tm_polygons("iso_a3",palette = "red") +
# tm_facets("iso_a3") +
# tm_shape(shape) +
# tmap_options(max.categories = 177) +
# tmap_options(limits = c(facets.plot = 177)) + 
# tm_dots() + 
# tm_legend(show=FALSE)

# tmap_save(tm,filename="C:/Users/ftw712/Desktop/map.pdf",height=40,width=10,units="cm")


# [[1]]$geometry
}


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

# load("C:/Users/ftw712/Desktop/isea3h.rda")
load("C:/Users/ftw712/Desktop/gbif_shapefile_geocoder/shapefile_making_R_scripts/data/isea3h.rda")

isea3h = isea3h %>%
filter(res == 5) %>% # actually resolution 5 since this data is indexed at 0
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

st_write(sf_obj, "C:/Users/ftw712/Desktop/isea3h_res6_shapefile/isea3h_res6_shapefile.shp")

# st_write(sf_obj, "C:/Users/ftw712/Desktop/isea3h_res5_shapefile/isea3h_res5_shapefile.shp")
# st_write(sf_obj, "C:/Users/ftw712/Desktop/polygon_grid_shapefile/polygon.shp")

# scp -r /cygdrive/c/Users/ftw712/Desktop/isea3h_res5_shapefile/ jwaller@c4gateway-vh.gbif.org:/home/jwaller/
# hdfs dfs -put isea3h_res5_shapefile/ isea3h_res6_shapefile
# hdfs dfs -ls 
# hdfs dfs -rm -r /isea3h_res6_shapefile


# spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "isea3h_res6_shapefile" "isea3h_res6_table" "polygon_geometry string, polygon_id int,  point_geometry string, decimallatitude double, decimallongitude double, gbifid bigint" "_c3" "_c4" "uat"
# spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "isea3h_res6_shapefile" "isea3h_res6_table" "polygon_geometry string, polygon_id int,  point_geometry string, decimallatitude double, decimallongitude double, gbifid bigint" "_c3" "_c4" "prod_h"

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

# create zoos herbaria shapefile 



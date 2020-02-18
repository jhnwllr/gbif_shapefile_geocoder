## gbif_shapefile_geocoder

General purpose **shapefile geocoder** that gives back **gbifids** for a given **shapefile**. That is, it will give you the points that fall within the polygons of the shapefile. For internal use. For downloads using shapefiles see https://data-blog.gbif.org/post/shapefiles/. 

Currently it is expected that the shapefile includes only **simple polygons** (no multi-polygons, points, or other shapes). Also the shapefile should include more than 1 or 2 polygons as this does not work for some reason.   

The project is built using [geospark](http://geospark.datasyslab.org/). 

**R scripts** for generating shapefiles can be found in **\shapefile_making_R_scripts**.

Any shapefile you want to use should be loaded into the cluster hdfs. For example the `shapefiles\country_centroid_shapefile` can be loaded like this: 

```
scp -r /cygdrive/c/Users/ftw712/Desktop/country_centroid_shapefile/ jwaller@c4gateway-vh.gbif.org:/home/jwaller/
hdfs dfs -put country_centroid_shapefile/ country_centroid_shapefile
hdfs dfs -ls 
```

Afterwards you should also copy the `gbif_shapefile_geocoder-assembly-0.1.0.jar` to the place you want to run it. 

```
scp -r /cygdrive/c/Users/ftw712/Desktop/gbif_shapefile_geocoder/scala/target/scala-2.11/gbif_shapefile_geocoder-assembly-0.1.0.jar jwaller@c5gateway-vh.gbif.org:/home/jwaller/
```

Finally you can run the jar using `spark2-submit`. 

These configurations are reccommended by **geospark**. `--conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g"`

You should also include 6 additional arguments on the command line: 

1. **shapefile**: the name of the shapefile in hdfs i.e. "country_centroid_shapefile" 
2. **table_name**: the name of the table you want to save results "country_centroid_table" 
3. **schema**: the hive schema to save the table. All results will have a **polygon_geometry** and **point_geometry** column. "polygon_geometry string, polygon_id int, iso2 string,  point_geometry string,  decimallatitude double, decimallongitude double" 
4. **col1**: name of lat column after join. Will be something like "_c4" depending on number of id variables in the shapefile. 
5. **col2**: name of long column after join. Will be something like "_c5" depending on number of id variables in the shapefile.
6. **database**:  The hdfs table where occurrences table lives ( **.occurrence_pipeline_hdfs** ) i.e. "uat" or "prod_h"

> Since there is a polygon_id and a iso2 column in the country_centroid_shapefile the join columns will be "_c4" and "_c5". Would be "_c3" "_c4" if is there was only one polygon id column.

```
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "country_centroid_shapefile" "country_centroid_table" "polygon_geometry string, polygon_id int, iso2 string,  point_geometry string, decimallatitude double, decimallongitude double, gbifid bigint" "_c4" "_c5" "uat"
```

Example using a polygon shapefile based off of https://www.discreteglobalgrids.org/

```
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "isea3h_res5_shapefile" "isea3h_res5_table" "polygon_geometry string, polygon_id int,  point_geometry string, decimallatitude double, decimallongitude double, gbifid bigint" "_c3" "_c4" "uat"
```` 


## build this project 

So far this has been working for me... There might be a faster option.

Go to project directory where `build.sbt` is located and run: 

```
sbt assembly 
```

This will produce the `scala/target/scala-2.11/gbif_shapefile_geocoder-assembly-0.1.0.jar` file that can be run on the cluster. 

Right now the save database is hard-coded to be **jwaller**. This needs to be changed if you want to save the results somewhere else. 


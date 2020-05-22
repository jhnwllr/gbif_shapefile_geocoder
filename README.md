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

You should also include 3 additional arguments on the command line: 

1. **shapefile**: the name of the shapefile in hdfs i.e. "country_centroid_shapefile" 
2. **save_table_name**: the name of the table you want to save results "country_centroid_table" 
3. **database**:  The hdfs table where occurrences table lives ( **.occurrence_hdfs** ) i.e. "uat" or "prod_h"

This will save a tsv table in hdfs with unique lat lon points that are within the polygons in the shapefile. 

```
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "country_centroid_shapefile" "country_centroid_table" "uat"
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "country_centroid_shapefile" "country_centroid_table" "prod"
```

Example using a polygon shapefile based off of https://www.discreteglobalgrids.org/

```
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "isea3h_res5_shapefile" "isea3h_res5_table" "uat"
spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" gbif_shapefile_geocoder-assembly-0.1.0.jar "isea3h_res5_shapefile" "isea3h_res5_table" "prod"
```` 

## working with results 

To do something meaningful with the results, you need to join with the rest of the occurrence data.  

```scala
import org.apache.spark.sql.DataFrame;
import org.apache.spark.sql.functions._;

val sqlContext = new org.apache.spark.sql.SQLContext(sc);
import sqlContext.implicits._;

// set the columns to join on 
val col1 = "lat" 
val col2 = "lon"
val database = "prod_h"
val save_table_name = "country_centroid_table"


// read in the geocoded table  
val df_geocode = spark.read.
option("sep", "\t").
option("header", "false").
option("inferSchema", "true").
csv(save_table_name).
withColumnRenamed("_c2","iso2").
withColumnRenamed("_c3","iso3").
withColumnRenamed("_c4","source").
withColumnRenamed("_c6","lat").
withColumnRenamed("_c7","lon").
select("iso2","iso3","source","lat","lon")


val df_occ = sqlContext.sql("SELECT * FROM " + database + ".occurrence_hdfs").
select("gbifid","decimallatitude","decimallongitude").
withColumnRenamed("decimallatitude","decimallatitude_occ").
withColumnRenamed("decimallongitude","decimallongitude_occ").
na.drop()

val df_output = df_geocode.join(df_occ, 
df_geocode(col1) === df_occ("decimallatitude_occ") && 
df_geocode(col2) === df_occ("decimallongitude_occ")
,"left").
drop("decimallatitude_occ").
drop("decimallongitude_occ").
cache() // you can cache this table if it is small enough 

df_output.groupBy("source").count()

```

## build this project 

So far this has been working for me... There might be a faster option.

Go to project directory where `build.sbt` is located and run: 

```
sbt assembly 
```

This will produce the `scala/target/scala-2.11/gbif_shapefile_geocoder-assembly-0.1.0.jar` file that can be run on the cluster. 


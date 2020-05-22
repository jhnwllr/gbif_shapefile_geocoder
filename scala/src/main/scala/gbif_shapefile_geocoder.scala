import com.vividsolutions.jts.geom.{Coordinate, Geometry, GeometryFactory}
import org.apache.log4j.{Level, Logger}
import org.apache.spark.serializer.KryoSerializer
import org.apache.spark.sql.SparkSession
import org.datasyslab.geospark.formatMapper.shapefileParser.ShapefileReader
import org.datasyslab.geospark.spatialRDD.SpatialRDD
import org.datasyslab.geospark.utils.GeoSparkConf
import org.datasyslab.geosparksql.utils.{Adapter, GeoSparkSQLRegistrator}
import org.datasyslab.geosparkviz.core.Serde.GeoSparkVizKryoRegistrator
import org.datasyslab.geospark.enums.GridType
import org.datasyslab.geospark.spatialOperator.{JoinQuery, KNNQuery, RangeQuery}
import org.datasyslab.geospark.enums.IndexType
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.SaveMode

// example spark-submit
// spark2-submit --conf "spark.driver.memory=10g" --conf "spark.network.timeout=1000s" --conf "spark.driver.maxResultSize=5g" country_centroid_geocoder-assembly-0.1.0.jar "country_centroid_shapefile" "country_centroid_table" "polygon_geometry string, polygon_id int, iso2 string,  point_geometry string, gbifid int"

object gbif_shapefile_geocoder  {

  def main(args: Array[String]): Unit = {
    println("start")

    // command line arguments supplied by user
    args.foreach(println)
    val shapefile = args(0) // name of shapefile that should be in hdfs
    val save_table_name = args(1) // name of table to save results
    val database = args(2) // uat or prod. which database are we running on?
	
  // geospark boilerplate
	var sparkSession:SparkSession = SparkSession.builder().config("spark.serializer",classOf[KryoSerializer].getName).
		config("spark.kryo.registrator", classOf[GeoSparkVizKryoRegistrator].getName).
		appName("gbif_shapefile_geocoder").getOrCreate()

	GeoSparkSQLRegistrator.registerAll(sparkSession)

  val points = sparkSession.sql("SELECT * FROM " + database + ".occurrence_hdfs").
    select("decimallatitude", "decimallongitude").
    na.drop().
    distinct()

  points.createOrReplaceTempView("points")

  val point_df = sparkSession.sql("""SELECT ST_Point(CAST(points.decimallongitude AS Decimal(24,20)), CAST(points.decimallatitude AS Decimal(24,20))) AS point_geometery, decimallatitude, decimallongitude FROM points""".stripMargin)
  point_df.createOrReplaceTempView("point_df")

  val buildOnSpatialPartitionedRDD = true // Set to TRUE only if run join query
  var usingIndex = true
  var considerBoundaryIntersection = true

  // for polygons
//  var spatialRDD = ShapefileReader.readToGeometryRDD(sparkSession.sparkContext, "country_centroid_shapefile")
  var spatialRDD = ShapefileReader.readToGeometryRDD(sparkSession.sparkContext, shapefile)
  spatialRDD.analyze()
  spatialRDD.spatialPartitioning(GridType.QUADTREE)
  spatialRDD.buildIndex(IndexType.QUADTREE, buildOnSpatialPartitionedRDD)

  // for points
  var pointRDD = new SpatialRDD[Geometry]
  pointRDD.rawSpatialRDD = Adapter.toRdd(point_df)
  pointRDD.analyze()
  pointRDD.spatialPartitioning(GridType.QUADTREE)
  pointRDD.buildIndex(IndexType.QUADTREE, buildOnSpatialPartitionedRDD)

  spatialRDD.spatialPartitioning(pointRDD.getPartitioner)

  val joinResultPairRDD = JoinQuery.SpatialJoinQueryFlat(pointRDD, spatialRDD, true, true).cache()

  val df_output = Adapter.toDf(joinResultPairRDD, sparkSession)

  println(df_output.count())
  df_output.show()
  // end geospark boilerplate

	// save the table
	df_output.
	write.format("csv").
	option("sep", "\t").
	option("header", "false").
	mode(SaveMode.Overwrite).
	save(save_table_name)
	
  println("Done")
   }

   }
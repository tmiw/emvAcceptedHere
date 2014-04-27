package controllers

import anorm._ 
import play.api._
import play.api.mvc._
import play.api.db._
import play.api.libs.json.Json
import play.api.Play.current
import play.api.data._
import play.api.data.Forms._

object Application extends Controller {
  
  def index = Action {
    Ok(views.html.index())
  }

  def indexWithLatLong(lat: Double, lon: Double) = Action {
    Ok(views.html.index())
  }
  
  def businessesAroundLatLong(lat_ur: Double, lon_ur: Double, lat_bl: Double, lon_bl: Double) = Action {
    DB.withConnection { implicit conn =>
      val result = SQL("""
          SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled"
          FROM "business_list" WHERE 
              ("business_latitude" >= {lat_bl} AND "business_latitude" <= {lat_ur}) AND
              ("business_longitude" >= {lng_bl} AND "business_longitude" <= {lng_ur})
          LIMIT 50""").on(
              "lng_ur" -> lon_ur, "lat_ur" -> lat_ur,
              "lng_bl" -> lon_bl, "lat_bl" -> lat_bl)
      Ok(Json.toJson(
              result().map(p => Map(
                  "id" -> p[Long]("id").toString,
                  "name" -> p[String]("business_name"),
                  "address" -> p[String]("business_address"),
                  "lat" -> p[Double]("business_latitude").toString,
                  "lng" -> p[Double]("business_longitude").toString,
                  "pin_enabled" -> p[Boolean]("business_pin_enabled").toString
              )).toList
      ))
    }
  }
  
  val addBusinessForm = Form(
      tuple(
          "name" -> nonEmptyText,
          "address" -> nonEmptyText,
          "latitude" -> nonEmptyText,
          "longitude" -> nonEmptyText,
          "pin_enabled" -> boolean
      )
  )
  
  def addBusiness = Action { implicit request =>
    val (name, address, latitude, longitude, pin_enabled) = addBusinessForm.bindFromRequest.get
    DB.withTransaction { implicit conn =>
      val result: Option[Long] = SQL("""
          INSERT INTO "business_list"
          ("business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled")
          VALUES
          ({name}, {address}, {latitude}, {longitude}, {pin_enabled})
          RETURNING "id"
      """).on(
          "name" -> name,
          "address" -> address,
          "latitude" -> java.lang.Double.parseDouble(latitude),
          "longitude" -> java.lang.Double.parseDouble(longitude),
          "pin_enabled" -> pin_enabled).executeInsert()
      Ok(Json.obj(
          "id" -> result.get,
          "name" -> name,
          "address" -> address,
          "lat" -> latitude,
          "lng" -> longitude,
          "pin_enabled" -> pin_enabled
      ))
    }
  }
}

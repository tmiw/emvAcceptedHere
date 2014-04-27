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
          SELECT "business_name", "business_address", "business_lat", "business_lng", "business_pin_enabled"
          FROM "business_list" WHERE 
              ("business_lat" >= {lat_bl} AND "business_lat" <= {lat_ur}) AND
              ("business_lng" >= {lng_bl} AND "business_lng" <= {lng_ur}) AND
          LIMIT 50""").on(
              "lng_ur" -> lon_ur, "lat_ur" -> lat_ur,
              "lng_bl" -> lon_bl, "lat_bl" -> lat_bl)
      Ok(
          Json.arr(
              result().map(p => Json.obj(
                  "name" -> p[String]("business_name"),
                  "address" -> p[String]("business_address"),
                  "lat" -> p[Double]("business_lat"),
                  "lng" -> p[Double]("business_lng"),
                  "pin_enabled" -> p[Boolean]("business_pin_enabled")
              ))
          )
      )
    }
  }
  
  val addBusinessForm = Form(
      tuple(
          "name" -> text,
          "address" -> text,
          "latitude" -> number,
          "longitude" -> number,
          "pin_enabled" -> checked("pin pad enabled")
      )
  )
  
  def addBusiness = Action { implicit request =>
    val (name, address, latitude, longitude, pin_enabled) = addBusinessForm.bindFromRequest.get
    DB.withTransaction { implicit conn =>
      SQL("""
          INSERT INTO "business_list"
          ("business_name", "business_address", "business_lat", "business_lng", "business_pin_enabled")
          VALUES
          ({name}, {address}, {latitude}, {longitude}, {pin_enabled})
      """).on(
          "name" -> name,
          "address" -> address,
          "latitude" -> latitude,
          "longitude" -> longitude,
          "pin_enabled" -> pin_enabled).execute
    }
    Ok(Json.obj(
        "name" -> name,
        "address" -> address,
        "lat" -> latitude,
        "lng" -> longitude,
        "pin_enabled" -> pin_enabled
    ))
  }
}
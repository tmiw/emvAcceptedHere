package controllers

import anorm._ 
import play.api._
import play.api.mvc._
import play.api.db._
import play.api.libs.json.Json
import play.api.Play.current
import play.api.data._
import play.api.data.Forms._

import com.typesafe.plugin._

object Application extends Controller {
  
  def index = Action {
    Ok(views.html.index())
  }

  def indexWithLatLong(lat: Double, lon: Double) = Action {
    Ok(views.html.index())
  }

  def about = Action {
    Ok(views.html.about())
  }
  
  def mcx = Action {
    Ok(views.html.mcx())
  }
  
  def news = Action {
    Ok(views.html.news())
  }
  
  def businessesAroundLatLong(lat_ur: Double, lon_ur: Double, lat_bl: Double, lon_bl: Double) = Action {
    DB.withConnection { implicit conn =>
      val result = SQL("""
          SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_mcx" 
          FROM "business_list" WHERE 
              ("business_latitude" >= {lat_bl} AND "business_latitude" <= {lat_ur}) AND
              ("business_longitude" >= {lng_bl} AND "business_longitude" <= {lng_ur})
          ORDER BY RANDOM()
          LIMIT 100""").on(
              "lng_ur" -> lon_ur, "lat_ur" -> lat_ur,
              "lng_bl" -> lon_bl, "lat_bl" -> lat_bl)
      Ok(Json.toJson(
              result().map(p => Map(
                  "id" -> p[Long]("id").toString,
                  "name" -> p[String]("business_name"),
                  "address" -> p[String]("business_address"),
                  "lat" -> p[Double]("business_latitude").toString,
                  "lng" -> p[Double]("business_longitude").toString,
                  "pin_enabled" -> p[Boolean]("business_pin_enabled").toString,
                  "contactless_enabled" -> p[Boolean]("business_contactless_enabled").toString,
                  "mcx_member" -> p[Boolean]("business_mcx").toString
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
          "pin_enabled" -> boolean,
          "contactless_enabled" -> boolean,
          "mcx_member" -> boolean
      )
  )
  
  def addBusiness = Action { implicit request =>
    val (name, address, latitude, longitude, pin_enabled, contactless_enabled, mcx_member) = addBusinessForm.bindFromRequest.get
    DB.withTransaction { implicit conn =>
      val result: Option[Long] = SQL("""
          INSERT INTO "business_list"
          ("business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_mcx")
          VALUES
          ({name}, {address}, {latitude}, {longitude}, {pin_enabled}, {contactless_enabled}, {mcx_member})
      """).on(
          "name" -> name,
          "address" -> address,
          "latitude" -> java.lang.Double.parseDouble(latitude),
          "longitude" -> java.lang.Double.parseDouble(longitude),
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "mcx_member" -> mcx_member).executeInsert()
      Ok(Json.obj(
          "id" -> result.get,
          "name" -> name,
          "address" -> address,
          "lat" -> latitude,
          "lng" -> longitude,
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "mcx_member" -> mcx_member
      ))
    }
  }
  
  def reportBusiness(id: Long) = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val result = SQL("""
          SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_mcx"
          FROM "business_list" WHERE
          "id" = {id}""").on("id" -> id)
      val business_info = result().toList.head
      val name = business_info[String]("business_name")
      val address = business_info[String]("business_address")
      val reason = request.body.asFormUrlEncoded.get("reason")(0)
      
      val mail = use[MailerPlugin].email
      mail.setSubject("Reported business")
      mail.setRecipient(Play.current.configuration.getString("email.to").get)
      mail.setFrom(Play.current.configuration.getString("email.from").get)
      mail.send("ID: " + id + "\r\n" + "Business name: " + name + "\r\n" + "Address: " + address + "\r\nReason:\r\n" + reason)
      
      Ok(Json.toJson(true))
    }
  }
}

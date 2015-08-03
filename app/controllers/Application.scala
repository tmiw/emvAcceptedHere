package controllers

import anorm._
import anorm.SqlParser._
import play.api._
import play.api.mvc._
import play.api.db._
import play.api.libs.json.Json
import play.api.Play.current
import play.api.data._
import play.api.data.Forms._
import play.api.libs.mailer._
import models._

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
  
  def businessesAroundLatLong(lat_ur: Double, lon_ur: Double, lat_bl: Double, lon_bl: Double, hideUnconfirmed: Boolean) = Action { implicit request =>
    val confirmed_sql = 
      if (hideUnconfirmed) 
        """
AND "business_confirmed_location" = true
""" else ""
    
    DB.withConnection { implicit conn =>
      // First we need an accurate count of the number of businesses in the bounding
      // box for the next query.
      val result_cols = """
        "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location"
        """
      val from_where_clause = """
        FROM "business_list" WHERE 
             ("business_latitude" >= {lat_bl} AND "business_latitude" <= {lat_ur}) AND
             ("business_longitude" >= {lng_bl} AND "business_longitude" <= {lng_ur})""" + confirmed_sql
      val result_count = SQL("""SELECT COUNT("id")""" + from_where_clause).on(
              "lng_ur" -> lon_ur, "lat_ur" -> lat_ur,
              "lng_bl" -> lon_bl, "lat_bl" -> lat_bl).as(scalar[Int].singleOpt).getOrElse(0)
      
      val num_rows = 300
      val result_probability = if (result_count > 0) num_rows / result_count.asInstanceOf[Double] else 0
      
      // This next query retrieves a random unique list of (up to) num_rows lat/long pairs. 
      // We could retrieve all of the business info here but some locations (such as malls)
      // can have multiple businesses with varying EMV status. 
      val lat_longs = SQL("""
         SELECT "t"."business_latitude", "t"."business_longitude" FROM (SELECT """ + result_cols + from_where_clause + """) "t"
         WHERE RANDOM() < {prob}
         ORDER BY RANDOM()
         LIMIT {rows}""").on(
              "prob" -> result_probability,
              "rows" -> num_rows,
              "lng_ur" -> lon_ur, "lat_ur" -> lat_ur,
              "lng_bl" -> lon_bl, "lat_bl" -> lat_bl)
      
      // The final query actually retrieves all businesses at the locations retrieved above.
      // This ensures that we have every single business in for example a mall.
      val lat_long_list = 
        lat_longs().map(p => (p[Double]("business_latitude"), p[Double]("business_longitude")))
                   .distinct
      
      if (lat_long_list.length > 0)
      {
        val lat_long_cond_string = 
          lat_long_list.map(q => """("business_latitude" = """ + q._1.toString() + 
                            """ AND "business_longitude" = """ + q._2.toString() + ") ")
     
        val result = SQL("""SELECT """ + result_cols + """ FROM "business_list" WHERE """ +
          lat_long_cond_string.mkString(" OR ") + confirmed_sql)
          
        Ok(Json.toJson(
                result().map(p => Map(
                    "id" -> p[Long]("id").toString,
                    "name" -> p[String]("business_name"),
                    "address" -> p[String]("business_address"),
                    "lat" -> p[Double]("business_latitude").toString,
                    "lng" -> p[Double]("business_longitude").toString,
                    "pin_enabled" -> p[Boolean]("business_pin_enabled").toString,
                    "contactless_enabled" -> p[Boolean]("business_contactless_enabled").toString,
                    "confirmed_location" -> p[Boolean]("business_confirmed_location").toString
                )).toList
        ))
      }
      else
      {
        Ok("[]")
      }
    }
  }
  
  val addBusinessForm = Form(
      tuple(
          "name" -> nonEmptyText,
          "address" -> nonEmptyText,
          "latitude" -> nonEmptyText,
          "longitude" -> nonEmptyText,
          "pin_enabled" -> boolean,
          "contactless_enabled" -> boolean
      )
  )
  
  def addBusiness = Action { implicit request =>
    val (name, address, latitude, longitude, pin_enabled, contactless_enabled) = addBusinessForm.bindFromRequest.get
    DB.withTransaction { implicit conn =>
      val result: Option[Long] = SQL("""
          INSERT INTO "business_list"
          ("business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location")
          VALUES
          ({name}, {address}, {latitude}, {longitude}, {pin_enabled}, {contactless_enabled}, {confirmed_location})
      """).on(
          "name" -> name,
          "address" -> address,
          "latitude" -> java.lang.Double.parseDouble(latitude),
          "longitude" -> java.lang.Double.parseDouble(longitude),
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "confirmed_location" -> true).executeInsert()
      Ok(Json.obj(
          "id" -> result.get,
          "name" -> name,
          "address" -> address,
          "lat" -> latitude,
          "lng" -> longitude,
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "confirmed_location" -> true
      ))
    }
  }
  
  def reportBusiness(id: Long) = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val result = SQL("""
          SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location"
          FROM "business_list" WHERE
          "id" = {id}""").on("id" -> id)
      val business_info = result().toList.head
      val name = business_info[String]("business_name")
      val address = business_info[String]("business_address")
      val reason = request.body.asFormUrlEncoded.get("reason")(0)
      val submitter_email = request.body.asFormUrlEncoded.get("submitter_email")(0)
      val mail = Email(
          "Reported business", 
          Play.current.configuration.getString("email.from").get,
          Seq(Play.current.configuration.getString("email.to").get),
          Some("ID: " + id + "\r\n" + "Submitter: " + submitter_email + "\r\n" + "Business name: " + name + "\r\n" + "Address: " + address + "\r\nReason:\r\n" + reason))
      MailerPlugin.send(mail)
      
      Ok(Json.toJson(true))
    }
  }
  
  def recentBusinesses = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val q = SQL("""
        SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location"
        FROM "business_list"
        ORDER BY "id" DESC
        LIMIT 10""")
      val result = q().map({ p => BusinessListing.CreateFromResult(p) }).toList
      Ok(views.html.recent_businesses(result))
    }
  }
  def sample_receipt_home = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val result = q().map(p => TerminalBrands(p[Int]("id"), p[String]("brand_name"))).toList
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm, 
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
      """)
      val imgs = q_imgs().map(p => TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file"))).toList
      
      Ok(views.html.receipts(result, imgs, None, None, None))
    }
  }
  
  def sample_receipts(brand: Int, method: String, cvm: String) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q().map(p => TerminalBrands(p[Int]("id"), p[String]("brand_name"))).toList
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm, 
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand} AND "method" = {method}::txn_method AND "cvm" = {cvm}::txn_cvm
      """).on("brand" -> brand, "method" -> method, "cvm" -> cvm)
      val imgs = q_imgs().map(p => TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file"))).toList
      
      Ok(views.html.receipts(brand_list, imgs, Some(brand), Some(method), Some(cvm)))
    }
  }
  
    def sample_receipts_wo_method(brand: Int) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q().map(p => TerminalBrands(p[Int]("id"), p[String]("brand_name"))).toList
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm,
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand}
      """).on("brand" -> brand)
      val imgs = q_imgs().map(p => TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file"))).toList
      
      Ok(views.html.receipts(brand_list, imgs, Some(brand), None, None))
    }
  }
    
  def sample_receipts_wo_cvm(brand: Int, method: String) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q().map(p => TerminalBrands(p[Int]("id"), p[String]("brand_name"))).toList
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm,
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand} AND "method" = {method}::txn_method
      """).on("brand" -> brand, "method" -> method)
      val imgs = q_imgs().map(p => TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file"))).toList
      
      Ok(views.html.receipts(brand_list, imgs, Some(brand), Some(method), None))
    }
  }
}

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
import javax.inject.Inject

object JavaContext {

  import play.mvc.Http
  import play.core.j.JavaHelpers

  def withContext[Status](block: => Status)(implicit header: RequestHeader): Status = {
    try {
      Http.Context.current.set(JavaHelpers.createJavaContext(header))
      block
    }
    finally {
      Http.Context.current.remove()
    }
  }
}

class Application @Inject() (mailerClient: MailerClient) extends Controller {
  
  def index = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.index()) }
  }

  def indexWithLatLong(lat: Double, lon: Double) = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.index()) }
  }

  def about = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.about()) }
  }
  
  def itemlegend = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.itemlegend()) }
  }
  
  def mcx = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.mcx()) }
  }
  
  def news = Action {
    implicit requestHeader: RequestHeader =>
    JavaContext.withContext { Ok(views.html.news()) }
  }
  
  def businessesAroundLatLong(lat_ur: Double, lon_ur: Double, lat_bl: Double, lon_bl: Double, hideUnconfirmed: Boolean, hideChains: Boolean) = Action { implicit request =>
    val confirmed_sql = 
      if (hideUnconfirmed) 
        """
AND "business_confirmed_location" = true
""" else ""
    val chain_sql = 
      if (hideChains)
        """
AND NOT EXISTS (SELECT 1 FROM "chain_list" WHERE "business_list"."business_name" LIKE ("chain_name" || '%'))
""" else ""
        
    DB.withConnection { implicit conn =>
      // First we need an accurate count of the number of businesses in the bounding
      // box for the next query.
      val result_cols = """
        "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_gas_pump_working", "business_confirmed_location"
        """
      val from_where_clause = """
        FROM "business_list" WHERE 
             ("business_latitude" >= {lat_bl} AND "business_latitude" <= {lat_ur}) AND
             ("business_longitude" >= {lng_bl} AND "business_longitude" <= {lng_ur})""" + confirmed_sql + chain_sql
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
      val ll_parser = RowParser[(Double, Double)] {
        case row => Success((row[Double]("business_latitude"), row[Double]("business_longitude")))
      }
      val lat_long_list = 
        lat_longs.as(ll_parser.*)
                 .distinct
      
      if (lat_long_list.length > 0)
      {
        val lat_long_cond_string = 
          lat_long_list.map(q => """("business_latitude" = """ + q._1.toString() + 
                            """ AND "business_longitude" = """ + q._2.toString() + ") ")
     
        val result = SQL("""SELECT """ + result_cols + """ FROM "business_list" WHERE """ +
          lat_long_cond_string.mkString(" OR ") + confirmed_sql)
        
        val result_parser = RowParser[Map[String, String]] {
          case p => 
            Success(Map(
                    "id" -> p[Long]("id").toString,
                    "name" -> p[String]("business_name"),
                    "address" -> p[String]("business_address"),
                    "lat" -> p[Double]("business_latitude").toString,
                    "lng" -> p[Double]("business_longitude").toString,
                    "pin_enabled" -> p[Boolean]("business_pin_enabled").toString,
                    "contactless_enabled" -> p[Boolean]("business_contactless_enabled").toString,
                    "confirmed_location" -> p[Boolean]("business_confirmed_location").toString,
                    "gas_pump_working" -> p[Boolean]("business_gas_pump_working").toString))
        }
        Ok(Json.toJson(result.as(result_parser.*)))
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
          "contactless_enabled" -> boolean,
          "gas_pump_working" -> boolean
      )
  )
  
  def addBusiness = Action { implicit request =>
    val (name, address, latitude, longitude, pin_enabled, contactless_enabled, gas_pump_working) = addBusinessForm.bindFromRequest.get
    DB.withTransaction { implicit conn =>
      val result: Option[Long] = SQL("""
          INSERT INTO "business_list"
          ("business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location", "business_gas_pump_working")
          VALUES
          ({name}, {address}, {latitude}, {longitude}, {pin_enabled}, {contactless_enabled}, {confirmed_location}, {gas_pump_working})
      """).on(
          "name" -> name,
          "address" -> address,
          "latitude" -> java.lang.Double.parseDouble(latitude),
          "longitude" -> java.lang.Double.parseDouble(longitude),
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "gas_pump_working" -> gas_pump_working,
          "confirmed_location" -> true).executeInsert()
      Ok(Json.obj(
          "id" -> result.get,
          "name" -> name,
          "address" -> address,
          "lat" -> latitude,
          "lng" -> longitude,
          "pin_enabled" -> pin_enabled,
          "contactless_enabled" -> contactless_enabled,
          "gas_pump_working" -> gas_pump_working,
          "confirmed_location" -> true
      ))
    }
  }
  
  def reportBusiness(id: Long) = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val result = SQL("""
          SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_confirmed_location"
          FROM "business_list" WHERE
          "id" = {id}""").on("id" -> id).as(RowParser[(String, String)] {
            case p => Success((p[String]("business_name"), p[String]("business_address")))
          }.*)
      val business_info = result.head
      val name = business_info._1
      val address = business_info._2
      val reason = request.body.asFormUrlEncoded.get("reason")(0)
      val submitter_email = request.body.asFormUrlEncoded.get("submitter_email")(0)
      val mail = Email(
          "Reported business", 
          Play.current.configuration.getString("email.from").get,
          Seq(Play.current.configuration.getString("email.to").get),
          Some("ID: " + id + "\r\n" + "Submitter: " + submitter_email + "\r\n" + "Business name: " + name + "\r\n" + "Address: " + address + "\r\nReason:\r\n" + reason))
      mailerClient.send(mail)
      
      Ok(Json.toJson(true))
    }
  }
  
  def recentBusinesses = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val q = SQL("""
        SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_gas_pump_working", "business_confirmed_location"
        FROM "business_list"
        ORDER BY "id" DESC
        LIMIT 10""")
      val q_parser = RowParser[BusinessListing] {
        case p => Success(BusinessListing.CreateFromResult(p))
      }
      val result = q.as(q_parser.*)
      
      val small_result = SQL("""
        SELECT "id", "business_name", "business_address", "business_latitude", "business_longitude", "business_pin_enabled", "business_contactless_enabled", "business_gas_pump_working", "business_confirmed_location"
        FROM "business_list"
        WHERE NOT EXISTS (SELECT 1 FROM "chain_list" WHERE "business_list"."business_name" LIKE ("chain_name" || '%'))
        ORDER BY "id" DESC
        LIMIT 10
        """).as(q_parser.*)
      
      val num_retailers = SQL("""
        SELECT COUNT(*) AS "cnt"
        FROM (SELECT "business_name" FROM "business_list" GROUP BY "business_name") "c"
        """).as(scalar[Int].*).head
      
      val num_small_retailers = SQL("""
        SELECT COUNT(*) AS "cnt"
        FROM (
            SELECT "business_name" 
            FROM "business_list" 
            WHERE NOT EXISTS (SELECT 1 FROM "chain_list" WHERE "business_list"."business_name" LIKE ("chain_name" || '%'))
            GROUP BY "business_name") "c"
        """).as(scalar[Int].*).head
        
      val num_businesses = SQL("""
        SELECT COUNT("id") AS "cnt"
        FROM "business_list"
        """).as(scalar[Int].*).head
        
      val num_small_businesses = SQL("""
        SELECT COUNT("id") AS "cnt"
        FROM "business_list"
        WHERE NOT EXISTS (SELECT 1 FROM "chain_list" WHERE "business_list"."business_name" LIKE ("chain_name" || '%'))
        """).as(scalar[Int].*).head
      
      val num_nfc_businesses = SQL("""
        SELECT COUNT("id") AS "cnt"
        FROM "business_list"
        WHERE "business_contactless_enabled" IS true""").as(scalar[Int].*).head
      
      val num_nfc_retailers = SQL("""
        SELECT COUNT(*) AS "cnt2"
        FROM (
            SELECT "business_name", count("business_contactless_enabled") AS "cnt" 
            FROM "business_list"
            GROUP BY "business_name", "business_contactless_enabled"
            HAVING "business_contactless_enabled" IS true 
            ORDER BY "cnt" DESC) x
        """).as(scalar[Int].*).head
      
      JavaContext.withContext { Ok(views.html.recent_businesses(result, small_result, num_businesses, num_small_businesses, num_nfc_businesses, num_nfc_retailers, num_retailers, num_small_retailers)) }
    }
  }
  
  def sample_receipt_home = Action { implicit request =>
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val result = q.as(RowParser[TerminalBrands] { 
        case p => Success(TerminalBrands(p[Int]("id"), p[String]("brand_name")))
      }.*)
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm, 
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
      """)
      val imgs = q_imgs.as(RowParser[TerminalReceipts] { 
        case p => Success(TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file")))
      }.*)
      
      JavaContext.withContext { Ok(views.html.receipts(result, imgs, None, None, None)) }
    }
  }
  
  def sample_receipts(brand: Int, method: String, cvm: String) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q.as(RowParser[TerminalBrands] { 
        case p => Success(TerminalBrands(p[Int]("id"), p[String]("brand_name")))
      }.*)
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm, 
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand} AND "method" = {method}::txn_method AND "cvm" = {cvm}::txn_cvm
      """).on("brand" -> brand, "method" -> method, "cvm" -> cvm)
      val imgs = q_imgs.as(RowParser[TerminalReceipts] { 
        case p => Success(TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file")))
      }.*)
      
      implicit requestHeader: RequestHeader =>
      JavaContext.withContext { Ok(views.html.receipts(brand_list, imgs, Some(brand), Some(method), Some(cvm))) }
    }
  }
  
    def sample_receipts_wo_method(brand: Int) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q.as(RowParser[TerminalBrands] { 
        case p => Success(TerminalBrands(p[Int]("id"), p[String]("brand_name")))
      }.*)
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm,
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand}
      """).on("brand" -> brand)
      val imgs = q_imgs.as(RowParser[TerminalReceipts] { 
        case p => Success(TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file")))
      }.*)
      
      implicit requestHeader: RequestHeader =>
      JavaContext.withContext { Ok(views.html.receipts(brand_list, imgs, Some(brand), None, None)) }
    }
  }
    
  def sample_receipts_wo_cvm(brand: Int, method: String) = Action {
    DB.withConnection { implicit conn =>
      val q = SQL("""
          SELECT "id", "brand_name" FROM "receipt_terminal_brands" ORDER BY "brand_name"
      """)
      val brand_list = q.as(RowParser[TerminalBrands] { 
        case p => Success(TerminalBrands(p[Int]("id"), p[String]("brand_name")))
      }.*)
      
      val q_imgs = SQL("""
          SELECT p.id as id, b.brand_name as brand_name, p.method::varchar(255) as method, p.cvm::varchar(255) as cvm,
                 p.image_file as image_file 
          FROM "receipts" p inner join "receipt_terminal_brands" b on b.id=p.brand
          WHERE "brand" = {brand} AND "method" = {method}::txn_method
      """).on("brand" -> brand, "method" -> method)
      val imgs = q_imgs.as(RowParser[TerminalReceipts] { 
        case p => Success(TerminalReceipts(p[Int]("id"), p[String]("brand_name"), p[String]("method"), p[String]("cvm"), p[String]("image_file")))
      }.*)
      
      implicit requestHeader: RequestHeader =>
      JavaContext.withContext { Ok(views.html.receipts(brand_list, imgs, Some(brand), Some(method), None)) }
    }
  }
}

package models

/**
 * @author mooneer
 */
object BusinessListing {
  def CreateFromResult(row: anorm.Row) : BusinessListing = {
    BusinessListing(
        row[Int]("id"),
        row[String]("business_name"), 
        row[String]("business_address"),
        row[Double]("business_latitude"), 
        row[Double]("business_longitude"),
        row[Boolean]("business_pin_enabled"),
        row[Boolean]("business_contactless_enabled"), 
        row[Boolean]("business_confirmed_location"),
        row[Boolean]("business_gas_pump_working"),
        row[Boolean]("business_pay_at_table"),
        row[Boolean]("business_unattended_terminals"),
        row[Boolean]("business_quick_chip"),
        row[Boolean]("business_is_chain"),
        row[Boolean]("business_emv_enabled")
    )
  }
}

case class BusinessListing(
    id: Int,
    name: String,
    address: String,
    latitude: Double,
    longitude: Double,
    pin_enabled: Boolean,
    contactless_enabled: Boolean,
    confirmed_location: Boolean,
    gas_pump_working: Boolean,
    pay_at_table: Boolean,
    unattended_terminals: Boolean,
    quick_chip: Boolean,
    is_chain: Boolean,
    emv_enabled: Boolean
)
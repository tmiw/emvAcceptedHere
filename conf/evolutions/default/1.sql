CREATE TABLE "business_list" (
    "id" bigint(20) NOT NULL AUTO_INCREMENT,
    "business_name" varchar(255) NOT NULL,
    "business_address" varchar(1024) NOT NULL,
    "business_latitude" double NOT NULL,
    "business_longitude" double NOT NULL,
    "business_pin_enabled" boolean NOT NULL)
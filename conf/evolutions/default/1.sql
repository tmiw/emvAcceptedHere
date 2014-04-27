CREATE TABLE "business_list" (
    "id" serial,
    "business_name" varchar(255) NOT NULL,
    "business_address" varchar(1024) NOT NULL,
    "business_latitude" double precision NOT NULL,
    "business_longitude" double precision NOT NULL,
    "business_pin_enabled" boolean NOT NULL)

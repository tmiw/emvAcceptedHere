CREATE TABLE "receipt_terminal_brands" (
    "id" serial,
    "brand_name" varchar(255) NOT NULL
)

INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ("Verifone")
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ("Ingenico")
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ("First Data")

-- Yes, Walmart etc. aren't terminal brands, but their terminals are integrated
-- into their POSes so they're considered brands here.
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ("Walmart")

CREATE TABLE "receipts" (
    "id" serial,
    "brand" int references "receipt_terminal_brands" ("id"),
    "method" as enum ('swiped', 'inserted', 'fallback', 'emv_contactless', 'msd_contactless') not null,
    "cvm" as enum ('none', 'signature', 'pin', 'mobile') not null,
    "image_file" varchar(1024) not null
)
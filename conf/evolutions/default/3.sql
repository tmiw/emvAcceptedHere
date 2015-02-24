CREATE TABLE "receipt_terminal_brands" (
    "id" serial primary key,
    "brand_name" varchar(255) NOT NULL
);

INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ('Verifone');
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ('Ingenico');
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ('First Data');

-- Yes, Walmart etc. aren't terminal brands, but their terminals are integrated
-- into their POSes so they're considered brands here.
INSERT INTO "receipt_terminal_brands" ("brand_name") VALUES ('Walmart');

CREATE TYPE txn_method AS ENUM ('swiped', 'inserted', 'fallback', 'emv_contactless', 'msd_contactless');
CREATE TYPE txn_cvm AS ENUM ('none', 'signature', 'pin', 'mobile');

CREATE TABLE "receipts" (
    "id" serial,
    "brand" int not null,
    "method" txn_method not null,
    "cvm" txn_cvm not null,
    "image_file" varchar(1024) not null,
    foreign key ("brand") references "receipt_terminal_brands" ("id")
);


# --- !Ups

CREATE TABLE "chain_list" (
    "id" serial,
    "chain_name" varchar(255) NOT NULL);

INSERT INTO "chain_list" ("chain_name") VALUES ('Target');
INSERT INTO "chain_list" ("chain_name") VALUES ('Walmart');
INSERT INTO "chain_list" ("chain_name") VALUES ('Sam''s Club');
INSERT INTO "chain_list" ("chain_name") VALUES ('Home Depot');
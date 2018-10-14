# --- !Ups
alter table "business_list" add column "business_is_chain" boolean not null default false;
update "business_list" set "business_is_chain"=true where "id" in (
	select distinct "bl"."id" from "business_list" "bl" inner join "chain_list" "cl" on "bl"."business_name" like ("cl"."chain_name" || '%'));
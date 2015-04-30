alter table business_list add column business_confirmed_location boolean not null default true;
alter table business_list drop column business_mcx;
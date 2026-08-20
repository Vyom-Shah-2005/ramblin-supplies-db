-- CS4400: Introduction to Database Systems (Summer 2026)
-- Project Phase III: Stored Procedures July 8th, 2026
-- Team 12

set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

use ramblin_supplies;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [1] add_owner()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new owner.  A new owner must have a unique
username. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_owner;
delimiter //
create procedure add_owner (in ip_username varchar(40), in ip_first_name varchar(100),
	in ip_last_name varchar(100), in ip_address varchar(500), in ip_birthdate date)
sp_main: begin
	-- ensure new owner has a unique username
	if ip_username in (select username from users) then leave sp_main; end if;
	if ip_username in (select username from employees) then leave sp_main; end if;

	insert into users(username, first_name, last_name, address, birthdate)
	values(ip_username, ip_first_name, ip_last_name, ip_address, ip_birthdate);

	insert into business_owners(username)
	values(ip_username);
end //
delimiter ;

-- [2] add_employee()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new employee without any designated driver or
worker roles.  A new employee must have a unique username and a unique tax identifier. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_employee;
delimiter //
create procedure add_employee (in ip_username varchar(40), in ip_first_name varchar(100),
	in ip_last_name varchar(100), in ip_address varchar(500), in ip_birthdate date,
    in ip_taxID varchar(40), in ip_hired date, in ip_employee_experience integer,
    in ip_salary integer)
sp_main: begin
    -- ensure new owner has a unique username
    -- ensure new employee has a unique tax identifier
	if ip_username in (select username from users) then leave sp_main; end if;
	if ip_taxID in (select taxID from employees) then leave sp_main; end if;

	insert into users(username, first_name, last_name, address, birthdate)
	values(ip_username, ip_first_name, ip_last_name, ip_address, ip_birthdate);

	insert into employees(username, taxID, hired, experience, salary)
	values(ip_username, ip_taxID, ip_hired, ip_employee_experience, ip_salary);
end //
delimiter ;

-- [3] add_driver_role()
-- -----------------------------------------------------------------------------
/* This stored procedure adds the driver role to an existing employee.  The
employee/new driver must have a unique license identifier. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_driver_role;
delimiter //
create procedure add_driver_role (in ip_username varchar(40), in ip_licenseID varchar(40),
	in ip_license_type varchar(40), in ip_driver_experience integer)
sp_main: begin
	-- ensure employee exists and is not a worker
    -- ensure new driver has a unique license identifier
	if ip_username not in (select username from employees) then leave sp_main; end if;
	if ip_username in (select username from workers) then leave sp_main; end if;
	if ip_username in (select username from drivers) then leave sp_main; end if;
	if ip_licenseID in (select licenseID from drivers) then leave sp_main; end if;

	insert into drivers(username, licenseID, license_type, successful_trips)
	values(ip_username, ip_licenseID, ip_license_type, ip_driver_experience);
end //
delimiter ;

-- [4] add_worker_role()
-- -----------------------------------------------------------------------------
/* This stored procedure adds the worker role to an existing employee. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_worker_role;
delimiter //
create procedure add_worker_role (in ip_username varchar(40))
sp_main: begin
	-- ensure employee exists and is not a driver
	if ip_username not in (select username from employees) then leave sp_main; end if;
	if ip_username in (select username from drivers) then leave sp_main; end if;
	if ip_username in (select username from workers) then leave sp_main; end if;

	insert into workers(username) 
	values(ip_username);
end //
delimiter ;

-- [5] add_product()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new product.  A new product must have a
unique barcode. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_product;
delimiter //
create procedure add_product (in ip_barcode varchar(40), in ip_name varchar(100),
	in ip_weight integer)
sp_main: begin
	-- ensure new product doesn't already exist
	if ip_barcode in (select barcode from products) then leave sp_main; end if;

	insert into products(barcode, iname, weight) 
	values(ip_barcode, ip_name, ip_weight);
end //
delimiter ;

-- [6] add_van()
-- -----------------------------------------------------------------------------
drop procedure if exists add_van;
delimiter //
create procedure add_van (in ip_id varchar(40), in ip_tag integer, in ip_fuel integer,
	in ip_capacity integer, in ip_sales integer, in ip_driven_by varchar(40))
sp_main: begin
	-- ensure new van doesn't already exist
    -- ensure that the delivery service exists
    -- ensure that a valid driver will control the van
	declare v_home_base varchar(40);

	if (ip_id, ip_tag) in (select id, tag from vans) then leave sp_main; end if;
	if ip_id not in (select id from delivery_services) then leave sp_main; end if;
	if ip_driven_by is null then leave sp_main; end if;
	if ip_driven_by not in (select username from drivers) then leave sp_main; end if;
	if ip_driven_by in (select driven_by from vans where driven_by is not null and id <> ip_id) then
		leave sp_main;
	end if;

	select home_base into v_home_base from delivery_services where id = ip_id;

	insert into vans(id, tag, fuel, capacity, sales, driven_by, located_at)
	values(ip_id, ip_tag, ip_fuel, ip_capacity, ip_sales, ip_driven_by, v_home_base);
end //
delimiter ;

-- [7] add_business()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new business.  A new business must have a
unique (long) name and must exist at a valid location, and have a valid rating.
And a resturant is initially "independent" (i.e., no owner), but will be assigned
an owner later for funding purposes. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_business;
delimiter //
create procedure add_business (in ip_long_name varchar(40), in ip_rating integer,
	in ip_spent integer, in ip_location varchar(40))
sp_main: begin
	-- ensure new business doesn't already exist
    -- ensure that the location is valid
    -- ensure that the rating is valid (i.e., between 1 and 5 inclusively)
	if ip_long_name in (select long_name from businesses) then leave sp_main; end if;
	if ip_location not in (select label from locations) then leave sp_main; end if;
	if ip_rating < 1 or ip_rating > 5 then leave sp_main; end if;

	insert into businesses(long_name, rating, spent, location)
	values(ip_long_name, ip_rating, ip_spent, ip_location);
end //
delimiter ;

-- [8] add_service()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new delivery service.  A new service must have
a unique identifier, along with a valid home base and manager. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_service;
delimiter //
create procedure add_service (in ip_id varchar(40), in ip_long_name varchar(100),
	in ip_home_base varchar(40), in ip_manager varchar(40))
sp_main: begin
	-- ensure new delivery service doesn't already exist
    -- ensure that the home base location is valid
    -- ensure that the manager is valid
	if ip_id in (select id from delivery_services) then leave sp_main; end if;
	if ip_home_base not in (select label from locations) then leave sp_main; end if;
	if ip_manager not in (select username from workers) then leave sp_main; end if;
	if ip_manager in (select manager from delivery_services where manager is not null) then
		leave sp_main;
	end if;

	insert into delivery_services(id, long_name, home_base, manager)
	values(ip_id, ip_long_name, ip_home_base, ip_manager);
end //
delimiter ;

-- [9] add_location()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new location that becomes a new valid van
destination.  A new location must have a unique combination of coordinates. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_location;
delimiter //
create procedure add_location (in ip_label varchar(40), in ip_x_coord integer,
	in ip_y_coord integer, in ip_space integer)
sp_main: begin
	-- ensure new location doesn't already exist
    -- ensure that the coordinate combination is distinct
	if ip_label in (select label from locations) then leave sp_main; end if;
	if (ip_x_coord, ip_y_coord) in (select x_coord, y_coord from locations) then
		leave sp_main;
	end if;

	insert into locations(label, x_coord, y_coord, space)
	values(ip_label, ip_x_coord, ip_y_coord, ip_space);
end //
delimiter ;

-- [10] start_funding()
-- -----------------------------------------------------------------------------
/* This stored procedure opens a channel for a business owner to provide funds
to a business. The owner and business must be valid. */
-- -----------------------------------------------------------------------------
drop procedure if exists start_funding;
delimiter //
create procedure start_funding (in ip_owner varchar(40), in ip_amount integer, in ip_long_name varchar(40), in ip_fund_date date)
sp_main: begin
	-- ensure the owner and business are valid
	if ip_owner not in (select username from business_owners) then leave sp_main; end if;
	if ip_long_name not in (select long_name from businesses) then leave sp_main; end if;
	if (ip_owner, ip_long_name) in (select username, business from fund) then leave sp_main; end if;

	insert into fund(username, invested, invested_date, business)
	values(ip_owner, ip_amount, ip_fund_date, ip_long_name);
end //
delimiter ;

-- [11] hire_employee()
-- -----------------------------------------------------------------------------
/* This stored procedure hires a worker to work for a delivery service.
If a worker is actively serving as manager for a different service, then they are
not eligible to be hired.  Otherwise, the hiring is permitted. */
-- -----------------------------------------------------------------------------
drop procedure if exists hire_employee;
delimiter //
create procedure hire_employee (in ip_username varchar(40), in ip_id varchar(40))
sp_main: begin
	-- ensure that the employee hasn't already been hired by that service
	-- ensure that the employee and delivery service are valid
    -- ensure that the employee isn't a manager for another service
	if ip_username not in (select username from workers) then leave sp_main; end if;
	if ip_id not in (select id from delivery_services) then leave sp_main; end if;
	if (ip_username, ip_id) in (select username, id from work_for) then leave sp_main; end if;
	if ip_username in ( select manager from delivery_services where manager is not null and id <> ip_id) then leave sp_main; end if;

	insert into work_for(username, id) values(ip_username, ip_id);
end //
delimiter ;

-- [12] fire_employee()
-- -----------------------------------------------------------------------------
/* This stored procedure fires a worker who is currently working for a delivery
service.  The only restriction is that the employee must not be serving as a manager 
for the service. Otherwise, the firing is permitted. */
-- -----------------------------------------------------------------------------
drop procedure if exists fire_employee;
delimiter //
create procedure fire_employee (in ip_username varchar(40), in ip_id varchar(40))
sp_main: begin
	-- ensure that the employee is currently working for the service
    -- ensure that the employee isn't an active manager
	if (ip_username, ip_id) not in (select username, id from work_for) then leave sp_main; end if;
	if ip_username in (select manager from delivery_services where manager is not null and id = ip_id) then leave sp_main; end if;

	delete from work_for where username = ip_username and id = ip_id;
end //
delimiter ;

-- [13] manage_service()
-- -----------------------------------------------------------------------------
/* This stored procedure appoints a worker who is currently hired by a delivery
service as the new manager for that service.  The only restrictions is that
the worker must not be working for any other delivery service. Otherwise, the appointment 
to manager is permitted.  The current manager is simply replaced. */
-- -----------------------------------------------------------------------------
drop procedure if exists manage_service;
delimiter //
create procedure manage_service (in ip_username varchar(40), in ip_id varchar(40))
sp_main: begin
	-- ensure that the employee is currently working for the service
    -- ensure that the employee isn't working for any other services
	if (ip_username, ip_id) not in (select username, id from work_for) then leave sp_main; end if;
	if ip_username in (select username from work_for where id <> ip_id) then leave sp_main; end if;

	update delivery_services set manager = ip_username where id = ip_id;
end //
delimiter ;

-- [14] takeover_van()
-- -----------------------------------------------------------------------------
/* This stored procedure allows a valid driver to take control of a van owned by 
the same delivery service. The current controller of the van is simply relieved 
of those duties. */
-- -----------------------------------------------------------------------------
drop procedure if exists takeover_van;
delimiter //
create procedure takeover_van (in ip_username varchar(40), in ip_id varchar(40),
	in ip_tag integer)
sp_main: begin
	-- ensure that the driver is not driving for another service
	-- ensure that the selected van is owned by the same service
    -- ensure that the employee is a valid driver
	if ip_username not in (select username from drivers) then leave sp_main; end if;
	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;
	if ip_username in (select driven_by from vans where driven_by is not null and id <> ip_id) then leave sp_main; end if;

	update vans set driven_by = ip_username where id = ip_id and tag = ip_tag;
end //
delimiter ;

-- [15] load_van()
-- -----------------------------------------------------------------------------
/* This stored procedure allows us to add some quantity of fixed-size packages of
a specific product to a van's payload so that we can sell them for some
specific price to other businesses.  The van can only be loaded if it's located
at its delivery service's home base, and the van must have enough capacity to
carry the increased number of items.

The change/delta quantity value must be positive, and must be added to the quantity
of the product already loaded onto the van as applicable.  And if the product
already exists on the van, then the existing price must not be changed. */
-- -----------------------------------------------------------------------------
drop procedure if exists load_van;
delimiter //
create procedure load_van (in ip_id varchar(40), in ip_tag integer, in ip_barcode varchar(40),
	in ip_more_packages integer, in ip_price integer)
sp_main: begin
	-- ensure that the van being loaded is owned by the service
	-- ensure that the product is valid
    -- ensure that the van is located at the service home base
	-- ensure that the quantity of new packages is greater than zero
	-- ensure that the van has sufficient capacity to carry the new packages
    -- add more of the product to the van
	declare v_home_base varchar(40);
	declare v_located_at varchar(40);
	declare v_capacity integer;
	declare v_current_total integer;

	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;
	if ip_barcode not in (select barcode from products) then leave sp_main; end if;
	if ip_more_packages <= 0 then leave sp_main; end if;

	select home_base into v_home_base from delivery_services where id = ip_id;
	select located_at, capacity into v_located_at, v_capacity
		from vans where id = ip_id and tag = ip_tag;
	if v_located_at <> v_home_base then leave sp_main; end if;

	select coalesce(sum(quantity), 0) into v_current_total
		from contain where id = ip_id and tag = ip_tag;
	if v_current_total + ip_more_packages > v_capacity then leave sp_main; end if;

	if (ip_id, ip_tag, ip_barcode) in (select id, tag, barcode from contain) then
		update contain set quantity = quantity + ip_more_packages
			where id = ip_id and tag = ip_tag and barcode = ip_barcode;
	else
		insert into contain(id, tag, barcode, quantity, price)
			values(ip_id, ip_tag, ip_barcode, ip_more_packages, ip_price);
	end if;
end //
delimiter ;

-- [16] refuel_van()
-- -----------------------------------------------------------------------------
/* This stored procedure allows us to add more fuel to a van. The van can only
be refueled if it's located at the delivery service's home base. */
-- -----------------------------------------------------------------------------
drop procedure if exists refuel_van;
delimiter //
create procedure refuel_van (in ip_id varchar(40), in ip_tag integer, in ip_more_fuel integer)
sp_main: begin
	-- ensure that the van being switched is valid and owned by the service
    -- ensure that the van is located at the service home base
	declare v_home_base varchar(40);
	declare v_located_at varchar(40);

	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;
	if ip_more_fuel <= 0 then leave sp_main; end if;

	select home_base into v_home_base from delivery_services where id = ip_id;
	select located_at into v_located_at from vans where id = ip_id and tag = ip_tag;
	if v_located_at <> v_home_base then leave sp_main; end if;

	update vans set fuel = fuel + ip_more_fuel where id = ip_id and tag = ip_tag;
end //
delimiter ;

-- [17] drive_van()
-- -----------------------------------------------------------------------------
/* This stored procedure allows us to move a single van to a new
location (i.e., destination). This will also update the respective driver's 
experience and van's fuel. The main constraints on the van(s) being able to 
move to a new  location are fuel and space.  A van can only move to a destination
if it has enough fuel to reach the destination and still move from the destination
back to home base.  And a van can only move to a destination if there's enough
space remaining at the destination. */
-- -----------------------------------------------------------------------------
drop function if exists fuel_required;
delimiter //
create function fuel_required (ip_departure varchar(40), ip_arrival varchar(40))
	returns integer reads sql data
begin
	if (ip_departure = ip_arrival) then return 0;
    else return (select 1 + truncate(sqrt(power(arrival.x_coord - departure.x_coord, 2) + power(arrival.y_coord - departure.y_coord, 2)), 0) as fuel
		from (select x_coord, y_coord from locations where label = ip_departure) as departure,
        (select x_coord, y_coord from locations where label = ip_arrival) as arrival);
	end if;
end //
delimiter ;

drop procedure if exists drive_van;
delimiter //
create procedure drive_van (in ip_id varchar(40), in ip_tag integer, in ip_destination varchar(40))
sp_main: begin
    -- ensure that the destination is a valid location
    -- ensure that the van isn't already at the location
    -- ensure that the van has enough fuel to reach the destination and (then) home base
    -- ensure that the van has enough space at the destination for the trip
	declare v_located_at varchar(40);
	declare v_fuel integer;
	declare v_driven_by varchar(40);
	declare v_home_base varchar(40);
	declare v_needed integer;
	declare v_dest_space integer;
	declare v_dest_count integer;

	if ip_destination not in (select label from locations) then leave sp_main; end if;
	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;

	select located_at, fuel, driven_by into v_located_at, v_fuel, v_driven_by
		from vans where id = ip_id and tag = ip_tag;
	if v_located_at = ip_destination then leave sp_main; end if;

	select home_base into v_home_base from delivery_services where id = ip_id;
	set v_needed = fuel_required(v_located_at, ip_destination) + fuel_required(ip_destination, v_home_base);
	if v_fuel < v_needed then leave sp_main; end if;

	select space into v_dest_space from locations where label = ip_destination;
	if v_dest_space is not null then
		select count(*) into v_dest_count from vans where located_at = ip_destination;
		if v_dest_count >= v_dest_space then leave sp_main; end if;
	end if;

	update vans set located_at = ip_destination,
		fuel = fuel - fuel_required(v_located_at, ip_destination)
		where id = ip_id and tag = ip_tag;

	if v_driven_by is not null then
		update drivers set successful_trips = successful_trips + 1 where username = v_driven_by;
	end if;
end //
delimiter ;

-- [18] purchase_product()
-- -----------------------------------------------------------------------------
/* This stored procedure allows a business to purchase products from a van
at its current location.  The van must have the desired quantity of the product
being purchased.  And the business must have enough money to purchase the
products.  If the transaction is otherwise valid, then the van and business
information must be changed appropriately.  Finally, we need to ensure that all
quantities in the payload table (post transaction) are greater than zero. */
-- -----------------------------------------------------------------------------
drop procedure if exists purchase_product;
delimiter //
create procedure purchase_product (in ip_long_name varchar(40), in ip_id varchar(40),
	in ip_tag integer, in ip_barcode varchar(40), in ip_quantity integer)
sp_main: begin
	-- ensure that the business is valid
    -- ensure that the van is valid and exists at the business's location
	-- ensure that the van has enough of the requested product
	-- update the van's payload
    -- update the monies spent and gained for the van and business
    -- ensure all quantities in the contain table are greater than zero
	declare v_biz_loc varchar(40);
	declare v_van_loc varchar(40);
	declare v_avail_qty integer;
	declare v_unit_price integer;

	if ip_long_name not in (select long_name from businesses) then leave sp_main; end if;
	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;
	if ip_quantity <= 0 then leave sp_main; end if;

	select location into v_biz_loc from businesses where long_name = ip_long_name;
	select located_at into v_van_loc from vans where id = ip_id and tag = ip_tag;
	if v_biz_loc <> v_van_loc then leave sp_main; end if;

	select quantity, price into v_avail_qty, v_unit_price
		from contain where id = ip_id and tag = ip_tag and barcode = ip_barcode;
	if v_avail_qty is null or v_avail_qty < ip_quantity then leave sp_main; end if;

	update contain set quantity = quantity - ip_quantity
		where id = ip_id and tag = ip_tag and barcode = ip_barcode;
	delete from contain
		where id = ip_id and tag = ip_tag and barcode = ip_barcode and quantity = 0;

	update vans set sales = sales + (ip_quantity * v_unit_price) where id = ip_id and tag = ip_tag;
	update businesses set spent = spent + (ip_quantity * v_unit_price) where long_name = ip_long_name;
end //
delimiter ;

-- [19] remove_product()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a product from the system.  The removal can
occur if, and only if, the product is not being carried by any vans. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_product;
delimiter //
create procedure remove_product (in ip_barcode varchar(40))
sp_main: begin
	-- ensure that the product exists
    -- ensure that the product is not being carried by any vans
	if ip_barcode not in (select barcode from products) then leave sp_main; end if;
	if ip_barcode in (select barcode from contain) then leave sp_main; end if;

	delete from products where barcode = ip_barcode;
end //
delimiter ;

-- [20] remove_van()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a van from the system.  The removal can
occur if, and only if, the van is not carrying any products.*/
-- -----------------------------------------------------------------------------
drop procedure if exists remove_van;
delimiter //
create procedure remove_van (in ip_id varchar(40), in ip_tag integer)
sp_main: begin
	-- ensure that the van exists
    -- ensure that the van is not carrying any products
	if (ip_id, ip_tag) not in (select id, tag from vans) then leave sp_main; end if;
	if (ip_id, ip_tag) in (select id, tag from contain) then leave sp_main; end if;

	delete from vans where id = ip_id and tag = ip_tag;
end //
delimiter ;

-- [21] remove_driver_role()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a driver from the system.  The removal can
occur if, and only if, the driver is not controlling any vans.  
The driver's information must be completely removed from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_driver_role;
delimiter //
create procedure remove_driver_role (in ip_username varchar(40))
sp_main: begin
	-- ensure that the driver exists
    -- ensure that the driver is not controlling any vans
    -- remove all remaining information
	if ip_username not in (select username from drivers) then leave sp_main; end if;
	if ip_username in (select driven_by from vans where driven_by is not null) then leave sp_main;
	end if;

	delete from drivers where username = ip_username;
end //
delimiter ;
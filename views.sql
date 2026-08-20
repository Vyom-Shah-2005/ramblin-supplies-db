-- CS4400: Introduction to Database Systems (Summer 2026)
-- Project Phase III: View SHELL [v0] May 16, 2026
-- Team 12
-- Deven Nahata (dnahata7)
-- Grant Webb (gwebb36)
-- Vyom Shah (vshah391)

set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

use ramblin_supplies;

-- [1] display_owner_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of an owner.
For each owner, it includes the owner's information, along with the number of
businesses for which they provide funds and the number of different places where
those businesses are located.  It also includes the highest and lowest ratings
for each of those businesses, as well as the total amount of debt based on the
monies spent purchasing products by all of those businesses. And if an owner
doesn't fund any businesses then display zeros for the highs, lows and debt. */
-- -----------------------------------------------------------------------------
create or replace view display_owner_view as
select
    bo.username,
    u.first_name,
    u.last_name,
    u.address,
    count(distinct f.business) as num_businesses,
    count(distinct b.location) as num_locations,
    coalesce(max(b.rating), 0) as highs,
    coalesce(min(b.rating), 0) as lows,
    coalesce(sum(b.spent), 0)  as debt
from business_owners bo
join users u on bo.username = u.username
left join fund f on bo.username = f.username
left join businesses b on f.business = b.long_name
group by bo.username, u.first_name, u.last_name, u.address;

-- [2] display_employee_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of an employee.
For each employee, it includes the username, tax identifier, salary, hiring date and
experience level, along with license identifer and driving experience (if applicable,
'n/a' if not), and a 'yes' or 'no' depending on the manager status of the employee. */
-- -----------------------------------------------------------------------------
create or replace view display_employee_view as
select
    e.username,
    e.taxID,
    e.salary,
    e.hired,
    e.experience,
    coalesce(d.licenseID, 'n/a') as licenseID,
    coalesce(cast(d.successful_trips as char), 'n/a') as successful_trips,
    case when ds.manager is not null then 'yes' else 'no' end as manager_status
from employees e
left join drivers d on e.username = d.username
left join delivery_services ds on e.username = ds.manager;

-- [3] display_driver_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of a driver.
For each driver, it includes the username, licenseID and drivering experience, along
with the number of vans that they are controlling. */
-- -----------------------------------------------------------------------------
create or replace view display_driver_view as
select
    d.username,
    d.licenseID,
    d.successful_trips,
    count(v.id) as num_vans
from drivers d
left join vans v on d.username = v.driven_by
group by d.username, d.licenseID, d.successful_trips;

-- [4] display_location_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of a location.
For each location, it includes the label, x- and y- coordinates, along with the
name of the business or service at that location, the number of vans as well as 
the identifiers of the vans at the location (sorted by the tag), and both the 
total and remaining capacity at the location. */
-- -----------------------------------------------------------------------------
create or replace view display_location_view as
select
    loc.label,
    coalesce(b.long_name, ds.long_name) as long_name,
    loc.x_coord,
    loc.y_coord,
    loc.space,
    count(v.tag) as num_vans,
    group_concat(concat(v.id, v.tag) order by v.tag separator ',') as van_ids,
    loc.space - count(v.tag) as remaining_capacity
from locations loc
join vans v on loc.label = v.located_at
left join businesses b on loc.label = b.location
left join delivery_services ds on loc.label = ds.home_base
group by loc.label, long_name, loc.x_coord, loc.y_coord, loc.space;

-- [5] display_product_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of the products.
For each product that is being carried by at least one van, it includes a list of
the various locations where it can be purchased, along with the total number of packages
that can be purchased and the lowest and highest prices at which the product is being
sold at that location. */
-- -----------------------------------------------------------------------------
create or replace view display_product_view as
select
    p.iname as product_name,
    v.located_at as location,
    sum(c.quantity) as amount_available,
    min(c.price) as low_price,
    max(c.price) as high_price
from contain c
join products p on c.barcode = p.barcode
join vans v on c.id = v.id and c.tag = v.tag
group by p.iname, v.located_at
order by p.iname, v.located_at;

-- [6] display_service_view()
-- -----------------------------------------------------------------------------
/* This view displays information in the system from the perspective of a delivery
service.  It includes the identifier, name, home base location and manager for the
service, along with the total sales from the vans.  It must also include the number
of unique products along with the total cost and weight of those products being
carried by the vans. */
-- -----------------------------------------------------------------------------
create or replace view display_service_view as
select
    ds.id,
    ds.long_name,
    ds.home_base,
    ds.manager,
    coalesce(van_totals.revenue, 0) as revenue,
    count(distinct c.barcode) as products_carried,
    coalesce(sum(c.price * c.quantity), 0) as cost_carried,
    coalesce(sum(p.weight * c.quantity), 0) as weight_carried
from delivery_services ds
left join (
    select id, sum(sales) as revenue
    from vans
    group by id
) van_totals on ds.id = van_totals.id
left join vans v on ds.id = v.id
left join contain c on v.id = c.id and v.tag = c.tag
left join products p on c.barcode = p.barcode
group by ds.id, ds.long_name, ds.home_base, ds.manager, van_totals.revenue;

-- [7] display_worker_training_view()
-- -----------------------------------------------------------------------------
/* This view displays information about workers from the perspective of training
and certifications. For each worker, it includes the worker's username, first name,
last name, the username of the worker who trains them if applicable, the number of
workers they train, and the number of certifications they hold. Workers with no
trainer, no trainees, or no certifications should still appear with appropriate
zero/null values. */
-- -----------------------------------------------------------------------------
create or replace view display_worker_training_view as
select
    w.username,
    u.first_name,
    u.last_name,
    tr.trainer as trainer,
    count(distinct tr2.trainee) as num_trainees,
    count(distinct wc.certification) as num_certifications
from workers w
join users u on w.username = u.username
left join trains tr on w.username = tr.trainee
left join trains tr2 on w.username = tr2.trainer
left join worker_certifications wc on w.username = wc.username
group by w.username, u.first_name, u.last_name, tr.trainer;
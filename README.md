# Ramblin' Supplies: Delivery Service Database

A relational database for a multi-business delivery network, built in MySQL. The project runs from a requirements spec through an EER model to a normalized schema, with all operations handled by stored procedures.

## Overview

Ramblin' Supplies models a delivery service that operates across a grid of locations. Business owners fund businesses. Employees become either drivers or warehouse workers. Delivery services hire workers and run fleets of vans. Drivers move vans between locations and burn fuel doing it. Vans carry product that businesses buy when the van is parked at their location.

The main design rule is that nothing writes to a table directly. Every insert, update, and delete goes through a stored procedure that checks its conditions first. If a check fails, such as a duplicate tax ID or a van without enough fuel to get back to home base, the procedure exits with `leave sp_main` and the database is left unchanged. There are no partial writes to clean up afterward.

## Features

- **Personnel:** register owners and employees, then assign employees to a driver or worker role. An employee cannot be both.
- **Services and fleets:** create delivery services with a home base and a manager, add vans, and hand van control from one driver to another within the same service.
- **Employment:** hire and fire workers and promote a worker to manager. A manager cannot be fired from the service they manage, and cannot manage two services at once.
- **Logistics:** load product onto vans at home base, refuel, and drive between locations. Fuel cost is based on distance.
- **Purchasing:** businesses buy product from a van at their location. Van sales and business debt update together.
- **Funding:** owners open funding channels to businesses with an amount and a date.
- **Reporting:** seven views that summarize the system from different angles.

## Tech stack

- **MySQL 8.0** for the schema, stored procedures, functions, and views
- **MySQL Workbench** for EER diagramming, development, and testing

## Schema

The EER model is in `er-diagram.pdf`.

| Table | Key columns |
|---|---|
| `users` | `username`, `first_name`, `last_name`, `address`, `birthdate` |
| `business_owners` | `username` |
| `employees` | `username`, `taxID`, `hired`, `experience`, `salary` |
| `drivers` | `username`, `licenseID`, `license_type`, `successful_trips` |
| `workers` | `username` |
| `businesses` | `long_name`, `rating`, `spent`, `location` |
| `delivery_services` | `id`, `long_name`, `home_base`, `manager` |
| `locations` | `label`, `x_coord`, `y_coord`, `space` |
| `vans` | `id`, `tag`, `fuel`, `capacity`, `sales`, `driven_by`, `located_at` |
| `products` | `barcode`, `iname`, `weight` |
| `contain` | `id`, `tag`, `barcode`, `quantity`, `price` |
| `fund` | `username`, `invested`, `invested_date`, `business` |
| `work_for` | `username`, `id` |
| `trains` | `trainer`, `trainee` |
| `worker_certifications` | `username`, `certification` |

Three design choices worth explaining:

**User specialization.** The `users` table holds the attributes everyone shares. `business_owners` and `employees` both key off `username`, and `employees` splits further into `drivers` and `workers`. Attributes that only apply to one role, like `licenseID` and `successful_trips`, live only in that role's table instead of sitting as nullable columns on one wide table. The rule that a person cannot be both a driver and a worker is enforced in the procedures: `add_driver_role` rejects any username already in `workers`, and `add_worker_role` does the reverse.

**Vans as a weak entity.** A van is identified by the pair `(id, tag)`, meaning the service that owns it plus a tag that is unique inside that fleet. Tag numbers can repeat across different services, so both columns are needed. Every table that references a van, including `contain`, carries both.

**Payload as a relationship table.** `contain` resolves the many-to-many between vans and products, with `quantity` and `price` as attributes of the relationship. Price sits here rather than on the product because the same product can sell for different amounts from different vans.

## Stored procedures

There are 21 procedures plus one helper function.

| # | Procedure | Purpose |
|---|---|---|
| 1 | `add_owner` | Register a business owner with a unique username |
| 2 | `add_employee` | Register an employee with a unique username and tax ID |
| 3 | `add_driver_role` | Make an employee a driver with a unique license |
| 4 | `add_worker_role` | Make an employee a warehouse worker |
| 5 | `add_product` | Add a product with a unique barcode |
| 6 | `add_van` | Add a van to a fleet, placed at the service home base |
| 7 | `add_business` | Create a business at a valid location with a rating of 1 to 5 |
| 8 | `add_service` | Create a delivery service with a home base and manager |
| 9 | `add_location` | Create a location with a coordinate pair no other location uses |
| 10 | `start_funding` | Open a funding channel from an owner to a business |
| 11 | `hire_employee` | Hire a worker to a delivery service |
| 12 | `fire_employee` | Release a worker unless they manage that service |
| 13 | `manage_service` | Promote a worker to manager of their service |
| 14 | `takeover_van` | Move van control to another driver in the same service |
| 15 | `load_van` | Add packages to a van's payload at home base |
| 16 | `refuel_van` | Add fuel to a van at home base |
| 17 | `drive_van` | Move a van to a destination, spend fuel, credit the driver |
| 18 | `purchase_product` | Sell packages from a van to a business at the same location |
| 19 | `remove_product` | Delete a product no van is carrying |
| 20 | `remove_van` | Delete a van carrying no products |
| 21 | `remove_driver_role` | Delete a driver who controls no vans |

### The `fuel_required` function

This helper returns the fuel cost of travelling between two locations:

```
1 + TRUNCATE(SQRT(POWER(Δx, 2) + POWER(Δy, 2)), 0)
```

That is Euclidean distance cut down to a whole number, plus one, so even neighbouring locations cost something to reach. It returns 0 when the departure and arrival are the same place.

`drive_van` calls this twice: once for the trip out, and once for the trip that would take the van from its destination back to home base. The move is refused unless the van has enough fuel for both. This is what stops a van from stranding itself somewhere it cannot return from. The procedure also checks that the destination has a free parking space before it commits the move, and adds one to the driver's `successful_trips` when the trip goes through.

## Views

| View | What it shows |
|---|---|
| `display_owner_view` | Per owner: businesses funded, distinct locations, rating range, total debt |
| `display_employee_view` | Per employee: pay and tenure, license details or `n/a`, manager yes or no |
| `display_driver_view` | Per driver: license, experience, number of vans controlled |
| `display_location_view` | Per location: occupant, coordinates, list of vans, space left |
| `display_product_view` | Per product and location: how much is available and the price range |
| `display_service_view` | Per service: revenue, distinct products, payload cost and weight |
| `display_worker_training_view` | Per worker: trainer, number of trainees, certifications held |

The views use `LEFT JOIN` with `COALESCE` so that records with nothing attached still show up. An owner who funds no businesses appears with zeros rather than disappearing from the results. `display_location_view` uses `GROUP_CONCAT` with an `ORDER BY` inside the aggregate so the van list for each location comes out sorted.

## Setup

Requires MySQL 8.0 or later.

```bash
mysql -u root -p -e "CREATE DATABASE ramblin_supplies;"
mysql -u root -p ramblin_supplies < stored_procedures.sql
mysql -u root -p ramblin_supplies < views.sql
```

Load the procedures before the views, since some views read tables the procedures fill.

You can also open each file in MySQL Workbench and run them in the same order.

Note that the table definitions are not included in this repository. The schema section above documents the structure, and the tables need to exist in `ramblin_supplies` before either file will load.

Both SQL files set their session context when they run:

```sql
SET GLOBAL TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SET GLOBAL SQL_MODE = 'ANSI,TRADITIONAL';
SET NAMES utf8mb4;
SET SQL_SAFE_UPDATES = 0;
USE ramblin_supplies;
```

Serializable isolation is a deliberate choice. `load_van` reads the van's current payload, compares it to capacity, then writes. Under a weaker isolation level, two loads running at the same time could both pass the capacity check and overfill the van.

## Usage

A full walkthrough from an empty database to a completed sale.

**Create two locations.** No two locations can share a coordinate pair.

```sql
CALL add_location('atl_base', 10, 20, 5);
CALL add_location('midtown', 14, 23, 3);
```

**Register a worker and set up a service.** The manager has to be a worker already, so the employee and the role come first.

```sql
CALL add_employee('jsmith', 'Jordan', 'Smith', '400 Tech Pkwy', '1998-03-14',
                  'TAX-1001', '2026-01-15', 3, 62000);
CALL add_worker_role('jsmith');
CALL add_service('rs_atl', 'Ramblin Supplies Atlanta', 'atl_base', 'jsmith');
```

**Register a driver and add a van.** Note that `add_van` takes no location. It looks up the service's home base and puts the van there.

```sql
CALL add_employee('mfranklin', 'Morgan', 'Franklin', '85 Fifth St', '1995-07-02',
                  'TAX-1002', '2026-02-01', 5, 58000);
CALL add_driver_role('mfranklin', 'D8829104', 'commercial', 0);
CALL add_van('rs_atl', 1, 100, 30, 0, 'mfranklin');
```

**Add a product and load it.** Loading only works at home base, and the payload has to fit inside the van's capacity.

```sql
CALL add_product('012345678905', 'Widget', 2);
CALL load_van('rs_atl', 1, '012345678905', 25, 3);
```

**Create a business and drive to it.** The distance from `atl_base` to `midtown` is the square root of 4² + 3², which is 5, so the trip costs 6 fuel each way. The van needs 12 available and has 100.

```sql
CALL add_business('Midtown Depot', 4, 0, 'midtown');
CALL drive_van('rs_atl', 1, 'midtown');
```

**Sell.** Van sales and business debt both move by quantity times unit price.

```sql
CALL purchase_product('Midtown Depot', 'rs_atl', 1, '012345678905', 10);
SELECT * FROM display_service_view WHERE id = 'rs_atl';
```

Every call either finishes completely or leaves the database untouched. Passing a barcode that does not exist to `load_van`, or a destination the van cannot return from, produces no error message and no change, so check the affected rows to confirm an operation actually took effect.

## Project structure

```
├── stored_procedures.sql    # 21 procedures + fuel_required
├── views.sql                # 7 reporting views
└── er-diagram.pdf           # EER model
```

## Contributors

Team 12, CS 4400 Introduction to Database Systems, Georgia Institute of Technology (Summer 2026).

- Deven Nahata
- Grant Webb
- Vyom Shah

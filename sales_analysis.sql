create database sales_analysis;
use sales_analysis;

drop table if exists customers;
create table customers(
customerkey int primary key,
customername varchar(100) not null,
maritalstatus varchar(7),
gender varchar(10),
annual_income decimal(12,2),
totalchildren int,
educationlevel varchar(70),
occupation varchar(60),
homeowner varchar(3));

drop table if exists product_categories;
create table product_categories(
productcategorykey int primary key,
category_name varchar(50));

drop table if exists product_subcategories;
create table product_subcategories(
productsubcategory_key int primary key,
subcategory_name varchar(100),
productcategorykey int,
foreign key (productcategorykey) references product_categories(productcategorykey));

drop table if exists territories;
create table territories(
salesterritorykey int primary key,
region varchar(100),
country varchar(100),
continent varchar(100));

drop table if exists products;
create table products(
productkey int primary key,
productsubcategory_key int,
product_sku varchar(200),
product_name varchar(200),
modelname varchar(200),
productcolor varchar(60),
productcost decimal(12,2),
productprice decimal(12,2),
foreign key(productsubcategory_key) references product_subcategories(productsubcategory_key));

drop table if exists returns;
create table returns(
returndate date,
territorykey int,
productkey int,
returnquantity int,
foreign key(territorykey) references territories(salesterritorykey),
foreign key(productkey) references products(productkey));

drop table if exists sales;
create table sales(
sales_key int auto_increment primary key,
orderdate date,
ordernumber varchar(50),
productkey int,
customerkey int,
territorykey int,
orderquantity int,
foreign key(productkey) references products(productkey),
foreign key(customerkey) references customers(customerkey),
foreign key(territorykey) references territories(salesterritorykey));

select * from customers;
select * from product_categories;
select * from product_subcategories;
select * from territories;
select * from products;
select * from returns;
select * from sales;

-- *********************Sales and order analysis ***********************

-- Total number of orders
select count(distinct ordernumber) as total_orders from sales;

-- Total revenue
select sum(p.productprice*s.orderquantity) as total_revenue
from sales as s inner join products as p on p.productkey = s.productkey;

-- Total Profit
select sum(s.orderquantity * (p.productprice - p.productcost)) as profit
from sales as s inner join products as p on p.productkey = s.productkey;

-- Top 5 Products generating maximum profit
with cte as(
select p.productkey, p.product_name, sum(s.orderquantity * (p.productprice - p.productcost)) as total_profit
from sales as s inner join products as p on p.productkey = s.productkey
group by 1,2)
select * from cte order by total_profit desc limit 5;

-- display total order value of each order
with total_order as(
select s.ordernumber, sum(p.productprice*s.orderquantity) as total_order_value
from sales as s inner join products as p on p.productkey = s.productkey group by 1)
select s.*, t.total_order_value
from sales as s left join total_order as t on s.ordernumber = t.ordernumber;

-- average order value 
select round(sum(p.productprice*s.orderquantity) / count(distinct ordernumber),2) as avg_order_value
from sales as s inner join products as p on p.productkey = s.productkey;

-- Sales trend over the years
select year(orderdate) as year, sum(p.productprice*s.orderquantity) as total_revenue
from sales as s inner join products as p on p.productkey = s.productkey group by 1;

-- Order trend over the years
select year(orderdate) as year, count(distinct ordernumber) as total_orders from sales group by year;

-- Year-over-Year sales growth
with current_year_cte as(
select year(orderdate) as year, sum(p.productprice*s.orderquantity) as total_revenue
from sales as s inner join products as p on p.productkey = s.productkey group by 1),
previous_year_cte as(
select *,
lag(total_revenue,1) over(order by year) as previous_year
from current_year_cte)
select year, total_revenue as current_year, previous_year,
concat(round((total_revenue - previous_year)*100/previous_year,2),'%') as yoy
from previous_year_cte;

-- ***********************Customer Analysis*****************************
-- Total number of customers
select count(customerkey) as customer_cnt from customers;

-- Gender distribution of customers
select gender, concat(round(count(*)*100.0/(select count(*) from customers),0),'%') as gender_distribution from customers group by gender;

-- Average annual income of customers
select round(avg(annual_income),2) as avg_income from customers;

-- Total number of customers who never placed any order
select count(*) as inactive_customers from customers where customerkey not in (select customerkey
from sales);

-- Customer distribution by region
select t.region, count(distinct s.customerkey) as customer_cnt
from sales as s 
inner join territories as t on s.territorykey = t.salesterritorykey
group by 1 order by customer_cnt desc;

-- Top 5 revenue-generating customers
with total_sales_cte as(
select s.customerkey, sum(p.productprice*s.orderquantity) as total_sales_amt
from sales as s inner join products as p on p.productkey = s.productkey
group by 1),
top_5_cust as(
select c.customerkey, c.customername, c1.total_sales_amt,
dense_rank() over(order by total_sales_amt desc) as sales_rk
from customers as c inner join total_sales_cte as c1 on c.customerkey = c1.customerkey)
select customerkey, customername, total_sales_amt from top_5_cust where sales_rk <= 5;

-- ************************* Product and Category Analysis **************************
-- Total number of product categories and number of subcategories in each category
select pc.category_name, count(ps.productsubcategory_key) as no_of_subcategories
from product_categories as pc inner join product_subcategories as ps on pc.productcategorykey = ps.productcategorykey
group by 1;

-- Number of products in each subcategory
select ps.productsubcategory_key, ps.subcategory_name, count(p.productkey) as no_of_products
from product_subcategories as ps inner join products as p on ps.productsubcategory_key = p.productsubcategory_key group by 1,2;

-- Total sales by each category
select pc.productcategorykey, pc.category_name, sum(p.productprice * s.orderquantity) as total_sales
from product_categories as pc
left join product_subcategories as ps on pc.productcategorykey = ps.productcategorykey
left join products as p on p.productsubcategory_key = ps.productsubcategory_key
left join sales as s on p.productkey = s.productkey
group by 1,2 order by 1;

-- number of sku's 
select count(distinct product_sku) as no_of_sku from products;

-- each sku's and revenue generated by each sku
select product_sku, product_name, coalesce(sum(p.productprice * s.orderquantity),0) as total_revenue
from products as p left join sales as s on p.productkey = s.productkey
group by 1,2;

-- total number of products or sku's never been sold
select count(productkey) as no_of_unsold_products from products where productkey not in (select productkey
from sales);

-- Top 10 SKU's by total sales
with top_performing_sku as(
select p.productkey, p.product_sku, p.product_name, sum(p.productprice*s.orderquantity) as total_sales
from products as p inner join sales as s on p.productkey = s.productkey
group by 1,2),
final_cte as(
select *,
dense_rank() over(order by total_sales desc) as sales_rn
from top_performing_sku)
select productkey, product_sku, product_name, total_sales from final_cte where sales_rn <= 10;

-- Top 3 best-selling SKUs in each category
with top_performing_products as(
select pc.category_name, p.product_sku, p.product_name, sum(p.productprice * s.orderquantity) as total_sales
from product_categories as pc
left join product_subcategories as ps on pc.productcategorykey = ps.productcategorykey
left join products as p on ps.productsubcategory_key = p.productsubcategory_key
left join sales as s on p.productkey = s.productkey
group by pc.category_name, p.product_sku, p.product_name),
top_3_products as(
select *,
dense_rank() over(partition by category_name order by total_sales desc) as rnk
from top_performing_products)
select category_name, product_sku, product_name, coalesce(total_sales,0) as total_sales
from top_3_products where rnk <= 3 and total_sales > 0;


-- ********************* Territory and return analysis *****************************
-- Total number of regions
select count(distinct region) as total_regions from territories;

-- Number of orders placed by each region
select t.region, count(distinct s.ordernumber) as no_of_orders
from territories as t left join sales as s on t.salesterritorykey = s.territorykey group by 1 order by no_of_orders desc;

-- Sales by region
select t.region, sum(p.productprice*s.orderquantity) as total_sales
from territories as t left join sales as s on t.salesterritorykey = s.territorykey inner join products as p on p.productkey = s.productkey
group by 1 order by total_sales desc;

-- Total returns
select sum(returnquantity) as total_returns from returns;

-- Year wise return distribution
select year(returndate) as year, sum(returnquantity) as total_returns from returns group by year;

-- No of returns by region
select t.region, coalesce(sum(r.returnquantity),0) as total_returns
from territories as t left join returns as r on t.salesterritorykey = r.territorykey group by 1 order by total_returns desc;

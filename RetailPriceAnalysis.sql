--

select top 100 *
from dbo.retail_price


select count(*)
from dbo.retail_price

select COLUMN_NAME
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME='retail_price'



-- 1] What is the distribution of prices for the products?

---- a. Distribution of price per product per year and sales generated
select product_id, unit_price, year, sum(qty) [Sales]
from dbo.retail_price
group by product_id, unit_price, year
order by 1,3,2

--select product_id, unit_price, year, qty
--from dbo.retail_price
--where product_id='bed1' 

---- b. Price at which most sales were generated per product
with cte1 as (
	select product_id, unit_price, year, sum(qty) [Sales],
	ROW_NUMBER() over(partition by product_id order by sum(qty) desc) as rno
	from dbo.retail_price
	group by product_id, unit_price, year
)
select *
from cte1
where rno=1
order by 1,3,2

---- c. Highest price product was sold at
with cte2 as (
	select product_id, unit_price, year, 
	ROW_NUMBER() over(partition by product_id order by unit_price desc) as rno
	from dbo.retail_price
	group by product_id, unit_price, year
)
select *
from cte2
where rno=1
order by 1,3,2

---- d. Lowest price product was sold at
with cte3 as (
	select product_id, unit_price, year, 
	ROW_NUMBER() over(partition by product_id order by unit_price) as rno
	from dbo.retail_price
	group by product_id, unit_price, year
)
select *
from cte3
where rno=1
order by 1,3,2



-- 2] Are there any noticable trends or patterns in price changes over time?

---- a. Yearly Trend
with price_cte as (
	select product_id, unit_price, year
	, Lag(unit_price) over(partition by product_id order by year) AS prev_unit_price
	from dbo.retail_price
	group by product_id, unit_price, year
)
select *, isnull((unit_price-prev_unit_price),0) [Diff. with Old Price]
from price_cte
--where product_id='computers1'
order by 1,3,2

---- b. Monthly Trend
with price_cte as (
	select product_id, unit_price,month, year
	, Lag(unit_price) over(partition by product_id order by year,month) AS prev_unit_price
	from dbo.retail_price
	group by product_id, unit_price,month, year
)
select *, isnull((unit_price-prev_unit_price),0) [Diff. with Old Price]
from price_cte
--where product_id='computers1'
order by 1,4,3,2


-- 3] How do different pricing strategies (e.g., dynamic pricing, fixed pricing) impact sales volume and revenue?

---- a.1. Pricing impact on Sales
select product_id,unit_price,  sum(qty) [Sales]
from dbo.retail_price
group by product_id,unit_price
order by 1,2

---- a.1. High Sales at price
with highSalesPrice as (
	select product_id,unit_price,  sum(qty) [Sales]
	, ROW_NUMBER() over(partition by product_id order by sum(qty) desc) rno
	, max(sum(qty)) over(partition by product_id) Max_Sale
	, FIRST_VALUE(unit_price) over(partition by product_id order by sum(qty) desc) Max_Sale_UnitPrice
	from dbo.retail_price
	group by product_id,unit_price
)
select product_id,unit_price, Sales
from highSalesPrice
where rno=1
order by 1,2


---- b.1. Pricing impact on Revenue
--select top 10 product_id, qty, freight_price,total_price
--, (qty*freight_price) as total_freight_price, (total_price +(qty*freight_price)) as Revenue_per_transaction
--from dbo.retail_price
--order by 1,2

with get_revenue as (
	select product_id, qty,unit_price, freight_price,total_price
	, (qty*freight_price) as total_freight_price, (total_price +(qty*freight_price)) as Revenue_per_transaction
	from dbo.retail_price
),
total_revenue_per_unitprice as (
		select product_id,unit_price, sum(Revenue_per_transaction) [Total_Revenue]
	--, ROW_NUMBER() over(partition by product_id order by sum(Revenue_per_transaction) desc) as rno
	--, max(sum(Revenue_per_transaction)) over(partition by product_id) as [Max_revenue_price]
	from get_revenue
	group by product_id, unit_price
),
max_revenue_at_price as (
	select *
	, ROW_NUMBER() over(partition by product_id order by Total_Revenue desc) as rno
	, max(Total_Revenue) over(partition by product_id) as [Max_revenue_price]
	from total_revenue_per_unitprice
	group by product_id, unit_price, Total_Revenue
)
select product_id,unit_price,Max_revenue_price
from max_revenue_at_price
where rno=1
order by 1
	

--4] How does freight price change with variations in product weight?
select product_weight_g, ceiling(avg(freight_price)) Avg_Frieght_Price
from dbo.retail_price
group by product_weight_g
order by 1, 2 desc

--5] How does the total number of customers affect the total quantity of products sold?
select product_id, sum(qty) TotalQtySold, sum(customers) TotalCustomers
from dbo.retail_price
group by product_id
order by 1


-- 6] How does our product pricing stack up against competitors' pricing?
---- >> -1 Less than that of competitor
---- >> 0  Equal to competitor
---- >> 1  More than that of competitor
with getprices as (
	select product_id
	,ceiling(avg(unit_price)) AvgUnitPrice  , CEILING(avg(product_score)) Avg_Product_Rating
	,ceiling(avg(comp_1)) Comp1_AvgUnitPrice, CEILING(avg(ps1)) Comp1_Avg_Product_Rating
	,ceiling(avg(comp_2)) Comp2_AvgUnitPrice, CEILING(avg(ps2)) Comp2_Avg_Product_Rating
	,ceiling(avg(comp_3)) Comp3_AvgUnitPrice, CEILING(avg(ps3)) Comp3_Avg_Product_Rating
	from dbo.retail_price
	group by product_id
),
compare as(
	select *,
	CASE
		WHEN AvgUnitPrice>Comp1_AvgUnitPrice THEN 1
		WHEN AvgUnitPrice<Comp1_AvgUnitPrice THEN -1
		ELSE 0
	END AS C1_UnitPrice,
	CASE
		WHEN Avg_Product_Rating>Comp1_Avg_Product_Rating THEN 1
		WHEN Avg_Product_Rating<Comp1_Avg_Product_Rating THEN -1
		ELSE 0
	END C1_Rating,
	CASE
		WHEN AvgUnitPrice>Comp2_AvgUnitPrice THEN 1
		WHEN AvgUnitPrice<Comp2_AvgUnitPrice THEN -1
		ELSE 0
	END AS C2_UnitPrice,
	CASE
		WHEN Avg_Product_Rating>Comp2_Avg_Product_Rating THEN 1
		WHEN Avg_Product_Rating<Comp2_Avg_Product_Rating THEN -1
		ELSE 0
	END C2_Rating,
	CASE
		WHEN AvgUnitPrice>Comp3_AvgUnitPrice THEN 1
		WHEN AvgUnitPrice<Comp3_AvgUnitPrice THEN -1
		ELSE 0
	END AS C3_UnitPrice,
	CASE
		WHEN Avg_Product_Rating>Comp3_Avg_Product_Rating THEN 1
		WHEN Avg_Product_Rating<Comp3_Avg_Product_Rating THEN -1
		ELSE 0
	END C3_Rating
	from getprices
)
select product_id,
C1_UnitPrice,C2_UnitPrice,C3_UnitPrice,
C1_Rating,C2_Rating,C3_Rating
from compare

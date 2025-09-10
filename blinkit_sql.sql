use blinkit_sales;
select * from blinkit_customer_feedback;
select * from blinkit_customers;
select * from blinkit_delivery_performance;
select * from blinkit_inventory;
select * from blinkit_inventorynew;
select * from blinkit_marketing_performance;
select * from blinkit_order_items;
select * from blinkit_orders;
select * from blinkit_products;

-- ________________________Descriptive analysis _______________________________

-- Total orders and distinct order 
select count(distinct(order_id)) from blinkit_orders;
select count(order_id)from blinkit_orders;

-- total customers 
select count(distinct(customer_id)) from blinkit_customers;

-- total products id and name
select count(distinct(product_id)) from blinkit_products;
select count(distinct(product_name)) from blinkit_products;
select * from blinkit_products;

-- Total categories
select count(distinct(category)) from blinkit_products;

-- ________________________ order analysis ____________________________________________________________

select * from blinkit_orders;
select min(order_date) from blinkit_orders;
select max(order_date) from blinkit_orders;

-- -------------------------Delivery Status ----------------------------------
select delivery_status, count(order_id) as count,
concat(round(count(distinct(order_id))/ (select count(distinct(order_id)) from blinkit_orders)*100, 0),"%") as contribution
from blinkit_orders
group by delivery_status 
order by contribution desc;

-- -------------------------payment method -----------------------------------
select payment_method, count(order_id) as count,
concat(round(count(distinct(order_id))/ (select count(distinct(order_id)) from blinkit_orders)*100, 0),"%") as contribution
from blinkit_orders
group by payment_method 
order by contribution desc;

-- ________________________ product analysis ____________________________________________________________
select * from blinkit_products;
select count(distinct(brand)) from blinkit_products;

select category, count(distinct(product_name)) as count_ 
from blinkit_products
group by category
order by count_ desc;

select product_name, count(distinct(product_id)) as count_ 
from blinkit_products
group by product_name
order by count_ desc;

select distinct(margin_percentage) from blinkit_products;
select distinct(shelf_life_days) from blinkit_products;

-- ___________________________Descriptive Analysis ___________________________________________________________________________

-- top products
select product_name, count(distinct(o.order_id)) as count_
from blinkit_orders as o
join blinkit_order_items as i 
on o.order_id= i.order_id
join blinkit_products as p
on i.product_id=p.product_id
group by product_name 
order by count_ desc
;

-- customer summary ___

select customer_segment, count(distinct(customer_id)) as count
from blinkit_customers
group by customer_segment;

select monthname(order_date) as month_,count(distinct(c.customer_id)) as cont
from blinkit_orders as o
join blinkit_customers as c
on o.customer_id=c.customer_id
where customer_segment = 'New'
group by month_ 
order by cont desc;

-- location summary -----------
select area, count(distinct(order_id)) as cnt
 from blinkit_customers as c
 join blinkit_orders as o
 on o.customer_id= c.customer_id
 group by area
 order by cnt desc;

select count(distinct(area)) from blinkit_customers;

-- __________________________ TREND Analysis ___________________________________________

select month(order_date) as month_no,monthname(order_date) as month_name,count(order_id) as order_count
from blinkit_orders
group by month_no,month_name
order by month_no asc;

select month(o.order_date) as month_no,monthname(o.order_date) as month_name,
count(case when c.customer_segment='New' then 1 end) as New_customers,
count(case when c.customer_segment='Premium' then 1  end) as Premium_customers,
count(case when c.customer_segment='Inactive' then 1 end) as Inactive_customers,
count(case when c.customer_segment='Regular' then 1 end) as Regular_customers,
count(o.customer_id) as total_customer
from blinkit_orders as o
join blinkit_customers as c
on o.customer_id= c.customer_id
group by month_no,month_name
order by month_no asc;

-- weekday vs weekend
select dayname(order_date) as day_name,count(order_id) as order_count
from blinkit_orders
group by day_name
order by order_count desc;

-- daywise volume
select day(order_date) as day_, count(order_id) as order_count
from blinkit_orders
group by day_
order by day_ asc;

-- cohort analysis _____________________
with firstpurchase as (
select customer_id,
min(date_format(order_date,'%Y-%m')) as cohort_Month
from blinkit_orders
group by customer_id
),
orderswithcohort as (
select o.customer_id,
fp.cohort_Month,
date_format(o.order_date,'%Y-%m') as order_Month
from blinkit_orders as o
join firstpurchase as fp
on o.customer_id= fp.customer_id
),
retention as (
select cohort_Month,
order_Month,
count(distinct(customer_id)) as Activecustomers
from orderswithcohort
group by cohort_Month,
order_Month ),

cohort_size as (
select cohort_Month,
count(distinct customer_id) as cohort_size
from orderswithcohort
group by cohort_Month
)
select 
r.cohort_Month,
r.order_Month,
r. Activecustomers,
c.cohort_size,
concat(round(r.Activecustomers* 100/c.cohort_size , 2),"%") as retention
from retention as r
join cohort_size as c
on r.cohort_Month= c. cohort_Month
order by r.cohort_Month, r.order_Month;

-- _____________________________ RFM Analysis (Recency, Frequency, Monetary)__________________________________________________________

-- step 1
-- recency
select customer_id,
datediff(curdate(),max(order_date)) as recency 
from blinkit_orders
group by customer_id;

-- step 2 frequency 
select customer_id, count(order_id) as frequency from blinkit_orders group by customer_id;

-- step 3 Monetray
select customer_id,sum(order_total) as Monetary 
from blinkit_orders 
group by customer_id;

-- final consolidated query

with RFM as (
select customer_id,
datediff(CURDATE(),max(order_date)) as Recency,
count(order_id) as Frequency,
sum(order_total) as Monetary
from blinkit_orders
group by customer_id
),
RFM_Scores as (
select customer_id,
-- Recency (lower = better, isliye reverse scoring)
ntile(5) over (order by Recency asc) as R_Score,
-- Frequency (higher = better)
ntile(5) over (order by Frequency desc) as f_score,
-- Monetary (higher = better)
ntile(5) over (order by Monetary desc) as M_score 
from RFM
)
select * ,
concat (R_Score,f_score,M_score) as RFM_Segment
from RFM_Scores
order by RFM_Segment desc;

-- _______________________________Product/Category Analysis_____________________________________________________________________

-- Category wise revence contribution
select p.category, 
sum(o.order_total) as Total,
concat(round(sum(o.order_total)/ 
(Select sum(order_total) from blinkit_orders)
 * 100 , 2),'%') 
as contribution
from blinkit_orders as o
join blinkit_order_items as i 
on o.order_id=i.order_id
join blinkit_products as p
on i.product_id = p. product_id
group by category
order by Total desc;

select p.product_name, 
sum(o.order_total) as Total,
concat(round(sum(o.order_total)/ (Select sum(order_total) from blinkit_orders) * 100 , 2),'%') as contribution
from blinkit_orders as o
join blinkit_order_items as i 
on o.order_id=i.order_id
join blinkit_products as p
on i.product_id = p. product_id
group by product_name
order by Total desc;




-- ____________________ CHurn analysis ___________________________________
with churn_data as (
select customer_id,
max(order_date)  as last_date,
abs(datediff('2024-01-05', max(order_date) ) )as last_order_date,
case 
when abs(datediff('2024-1-05' , max(order_date))) > 90 
then 'churned' else 'Active_Customer' end as churn_status
from blinkit_orders 
group by customer_id)

select 
count(case when churn_status = 'churned' then 1 end )
as churned_count,
count(case when churn_status = 'Active_Customer' then 1 end )
as Active_Customer_count,
concat(round(count(case when churn_status = 'churned' then 1 end )
             / count(*) * 100,0),'%') as churned_per,
concat(round(count(case when churn_status = 'Active_Customer' then 1 end )
             / count(*) * 100,0),'%') as Active_Customer_per
from churn_data;


-- _______________________Basket ______________________________________________
with tabel as (
select o.order_id,
p.product_id,
p.product_name
from blinkit_orders as o
join blinkit_order_items as i
on o.order_id=i.order_id
join blinkit_products as p
on p.product_id=i.product_id
)

select a.product_name as product_1,
b.product_name as product_2,
count(distinct a.order_id) as times_bought_together
from tabel as a
join tabel as b
on a.order_id=b.order_id
and a.product_id< b.product_id
group by a.product_name,b.product_name 
order by times_bought_together desc
limit 10;

-- products purchased together   
SELECT COUNT(*) AS orders_with_multiple_items
FROM (
  SELECT order_id
  FROM blinkit_order_items
  GROUP BY order_id
  HAVING COUNT(DISTINCT product_id) > 1
) t;

-- every order_id only have 1 product thats why mba fails here 

select distinct o.order_id,
count(distinct p.product_id) as product_count
from blinkit_orders as o
join blinkit_order_items as i
on o.order_id=i.order_id
join blinkit_products as p
on p.product_id=i.product_id
group by order_id
order by product_count desc;

-- Order frequency by customer segment.
select c.customer_segment,
count(distinct o.order_id ) as order_count,
count(distinct o.customer_id) as total_customer,
round(count(distinct o.order_id) / count(distinct o.customer_id),2) as OrderPerCustomer,
round(sum(o.order_total),0) as order_value,
round(sum(o.order_total)/count(distinct o.customer_id),2) as ordervaluePerCustomer
from blinkit_orders as o
join blinkit_customers as c
on o.customer_id=c.customer_id
group by customer_segment
order by order_count desc;


-- _____________________Product Performance_________________________________________________________

select product_name,
count(distinct o.order_id) as Order_count,
count(distinct o.customer_id) as customer_count,
round(sum(o.order_total),0) as order_value,
round(count(distinct o.order_id)/count(distinct o.customer_id) , 2) as orderPerCustomer,
round(sum(o.order_total) / count(distinct o.customer_id), 2) as ValuePerCustomer
from blinkit_orders as o
join blinkit_order_items as i
on o.order_id=i.order_id
join blinkit_products as p
on p.product_id = i.product_id
group by product_name
order by Order_count desc;
select product_name,
round(sum( quantity *unit_price), 2) as valueContribution,
concat(round(sum( quantity *unit_price)/ 
(select sum( quantity *unit_price) from blinkit_order_items)*100 , 2),'%') as valueContribution
from blinkit_order_items as i
join blinkit_products as p 
on p.product_id = i.product_id
group by product_name
order by valueContribution desc;


-- stock out analysis
WITH stock_data AS (
    SELECT 
        p.product_name,
        i.date,
        i.stock_received
    FROM blinkit_inventory i
    JOIN blinkit_products p 
        ON i.product_id = p.product_id
),
stockouts AS (
    SELECT 
        product_name,
        date,
        CASE WHEN stock_received = 0 THEN 1 ELSE 0 END AS is_stockout
    FROM stock_data
)
SELECT 
    product_name,
    COUNT(CASE WHEN is_stockout = 1 THEN 1 END) AS stockout_days,
    COUNT(*) AS total_days,
    ROUND(COUNT(CASE WHEN is_stockout = 1 THEN 1 END) * 100.0 / COUNT(*), 2) AS stockout_percentage
FROM stockouts
GROUP BY product_name
ORDER BY stockout_percentage DESC;

-- __________________________________Marketing & Campaign Analysis__________________________________________
select * from blinkit_marketing_performance;

select distinct campaign_name from blinkit_marketing_performance;

select  campaign_name , target_audience,
count(*)as count_,
round(sum(spend),0) as Total_spend,
round(sum(revenue_generated),0) as revenue_generated,
sum(clicks) ,
sum(conversions) ,
concat(round(sum(conversions)/sum(clicks)*100,2),'%') as conversion_rate,
concat(round((sum(revenue_generated)-sum(spend))/ sum(spend) * 100 ,0), '%') as ROI,
round(sum(spend)/ sum(conversions),2) as Customer_Acquisition_Cost,
round(sum(revenue_generated)/sum(conversions),2) as revenue_per_conversion
from blinkit_marketing_performance
group by campaign_name,target_audience with rollup;

select  target_audience,
count(*)as count_,
round(sum(spend),0) as Total_spend,
round(sum(revenue_generated),0) as revenue_generated,
sum(clicks) ,
sum(conversions) ,
concat(round(sum(conversions)/sum(clicks)*100,2),'%') as conversion_rate,
concat(round((sum(revenue_generated)-sum(spend))/ sum(spend) * 100 ,0), '%') as ROI,
round(sum(spend)/ sum(conversions),2) as Customer_Acquisition_Cost 
from blinkit_marketing_performance
group by target_audience ;

select  channel,
count(*)as count_,
round(sum(spend),0) as Total_spend,
round(sum(revenue_generated),0) as revenue_generated,
sum(clicks) as clicks ,
sum(conversions)  as conversion ,
concat(round(sum(conversions)/sum(clicks)*100,2),'%') as conversion_rate,
concat(round((sum(revenue_generated)-sum(spend))/ sum(spend) * 100 ,0), '%') as ROI,
round(sum(spend)/ sum(conversions),2) as Customer_Acquisition_Cost 
from blinkit_marketing_performance
group by channel ;

-- _________________________________Customer Feedback Analysis_____________________________________
select * from blinkit_customer_feedback;
select rating,
count(distinct feedback_id) as count_,
concat(round(count(distinct feedback_id)/
(select count(distinct feedback_id) from blinkit_customer_feedback) *100,2),'%')
as contribution
 from blinkit_customer_feedback
group by rating;

SELECT 
    p.product_name,
    ROUND(AVG(f.rating), 2) AS avg_rating,
    COUNT(f.feedback_id) AS total_reviews
FROM blinkit_customer_feedback as f
join blinkit_order_items as i
on f.order_id= i.order_id
JOIN blinkit_products p 
ON i.product_id = p.product_id
GROUP BY p.product_name
ORDER BY avg_rating DESC;


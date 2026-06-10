CREATE DATABASE IF NOT EXISTS amazonecommerce;
USE amazonecommerce;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

create table customers(
CustomerID INT PRIMARY KEY,
Customer_Age int not null,
Customer_Gender varchar(10) not null
);

DROP TABLE IF EXISTS orders;

CREATE TABLE orders(
    OrderID BIGINT PRIMARY KEY,
    OrderDate DATE NOT NULL,
    Delivery_Date DATE,
    CustomerID BIGINT NOT NULL,
    Location VARCHAR(100),
    Zone VARCHAR(50),
    Delivery_Type VARCHAR(50),
    Product_Category VARCHAR(100),
    SubCategory VARCHAR(100),
    Product VARCHAR(500),
    Unit_Price DECIMAL(10,2),
    Shipping_Fee INT,
    Order_Quantity INT,
    Sale_Price DECIMAL(10,2) NOT NULL,
    Status VARCHAR(50) NOT NULL,
    Reason VARCHAR(200),
    Rating INT
);

select count(*) from customers;
select count(*) from orders;
-- 14 Identify the top 5 most valuable customers using a composite score that   combines three key metrics: (SQL)
-- 1. Total Revenue (50% weight): The total amount of money spent by the customer.
-- 2. Order Frequency (30% weight): The number of orders placed by the customer, indicating their loyalty and engagement.
-- 3. Average Order Value (20% weight): The average value of each order placed by the customer, reflecting the typical transaction size.

WITH customer_metrics AS
(
    SELECT
        c.CustomerID,
        c.Customer_Age,
        c.Customer_Gender,
        SUM(o.Sale_Price) AS Total_Revenue,
        COUNT(o.OrderID) AS Order_Frequency,
        AVG(o.Sale_Price) AS Avg_Order_Value
    FROM customers c
    JOIN orders o
        ON c.CustomerID = o.CustomerID
    GROUP BY
        c.CustomerID,
        c.Customer_Age,
        c.Customer_Gender
)

SELECT
    ROW_NUMBER() OVER (ORDER BY Composite_Score DESC) AS Customer_Rank,
    CustomerID,
    Customer_Age,
    Customer_Gender,
    Total_Revenue,
    Order_Frequency,
    ROUND(Avg_Order_Value,2) AS Avg_Order_Value,
    ROUND(Composite_Score,2) AS Composite_Score
FROM
(
    SELECT *,
           (Total_Revenue * 0.50) +
           (Order_Frequency * 0.30) +
           (Avg_Order_Value * 0.20) AS Composite_Score
    FROM customer_metrics
) t
ORDER BY Composite_Score DESC
LIMIT 5;
-- 15. Calculate the month-over-month growth rate in total revenue across the entire dataset. (SQL)

WITH monthly_revenue AS
(
    SELECT
        DATE_FORMAT(OrderDate,'%Y-%m') AS Month,
        SUM(Sale_Price) AS Total_Revenue
    FROM orders
    GROUP BY DATE_FORMAT(OrderDate,'%Y-%m')
)
SELECT
    Month,
    Total_Revenue,
    LAG(Total_Revenue) OVER(ORDER BY Month) AS Previous_Month_Revenue,
    ROUND(
        (
            (Total_Revenue - LAG(Total_Revenue) OVER(ORDER BY Month))
            /
            LAG(Total_Revenue) OVER(ORDER BY Month)
        ) * 100,
        2
    ) AS MoM_Growth_Rate_Percentage
FROM monthly_revenue
ORDER BY Month;

-- 16.Calculate the rolling 3-month average revenue for each product category. (SQL)

WITH monthly_category_revenue AS
(
    SELECT
        Product_Category,
        DATE_FORMAT(OrderDate,'%Y-%m') AS Revenue_Month,
        SUM(Sale_Price) AS Monthly_Revenue
    FROM orders
    GROUP BY
        Product_Category,
        DATE_FORMAT(OrderDate,'%Y-%m')
)

SELECT
    Product_Category,
    Revenue_Month,
    Monthly_Revenue,

    ROUND(
        AVG(Monthly_Revenue)
        OVER(
            PARTITION BY Product_Category
            ORDER BY Revenue_Month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS Rolling_3_Month_Avg_Revenue

FROM monthly_category_revenue
ORDER BY
    Product_Category,
    Revenue_Month;
    
-- 17.Update the orders table to apply a 15% discount on the `Sale Price` for orders placed by customers who have made at least 10 orders. (SQL)

SET SQL_SAFE_UPDATES = 0;

UPDATE orders
SET Sale_Price = ROUND(Sale_Price * 0.85, 2)
WHERE CustomerID IN (
    SELECT CustomerID
    FROM (
        SELECT CustomerID
        FROM orders
        WHERE Status NOT IN ('Cancelled', 'Returned')
        GROUP BY CustomerID
        HAVING COUNT(OrderID) >= 10
    ) AS eligible_customers
);

SET SQL_SAFE_UPDATES = 1;


-- 18. Calculate the average number of days between consecutive orders for customers who have placed at least five orders. (SQL)

SELECT
    ROUND(
        AVG(DATEDIFF(Delivery_Date, OrderDate)),
        2
    ) AS Avg_Delivery_Days
FROM orders
WHERE Delivery_Date IS NOT NULL
  AND OrderDate IS NOT NULL;
  
-- 19. Identify customers who have generated revenue that is more than 30% higher than the average revenue per customer. (SQL)

WITH customer_revenue AS (
    SELECT
        CustomerID,
        SUM(Sale_Price) AS Total_Revenue
    FROM orders
    GROUP BY CustomerID
),

average_revenue AS (
    SELECT
        AVG(Total_Revenue) AS Avg_Revenue
    FROM customer_revenue
)

SELECT
    cr.CustomerID,
    cr.Total_Revenue,
    ROUND(ar.Avg_Revenue, 2) AS Avg_Revenue
FROM customer_revenue cr
CROSS JOIN average_revenue ar
WHERE cr.Total_Revenue > ar.Avg_Revenue * 1.30
ORDER BY cr.Total_Revenue DESC;

-- 20. Determine the top 3 product categories that have shown the highest increase in sales over the past year compared to the previous year. (SQL)

WITH yearly_sales AS (
    SELECT
        Product_Category,
        YEAR(OrderDate) AS Sales_Year,
        SUM(Sale_Price) AS Total_Sales
    FROM orders
    GROUP BY Product_Category,
             YEAR(OrderDate)
),

sales_growth AS (
    SELECT
        Product_Category,
        Sales_Year,
        Total_Sales,
        LAG(Total_Sales) OVER (
            PARTITION BY Product_Category
            ORDER BY Sales_Year
        ) AS Previous_Year_Sales
    FROM yearly_sales
)

SELECT
    Product_Category,
    Sales_Year,
    Total_Sales,
    Previous_Year_Sales,
    ROUND(
        Total_Sales - Previous_Year_Sales,
        2
    ) AS Sales_Increase
FROM sales_growth
WHERE Previous_Year_Sales IS NOT NULL
ORDER BY Sales_Increase DESC
LIMIT 3;
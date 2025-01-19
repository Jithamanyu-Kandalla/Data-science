USE be;

# Question 1
# The company wants to see if the shippers are delivering 
# the orders on weekends or not.
# So for that, they want to see the number of orders 
# delivered on a particular weekday.
# Print DayName, count of orders delivered on that day 
# in the descending order of count of orders.

SELECT 
    DAYNAME(DeliveryDate) as DayName,
    COUNT(*) as OrderCount
FROM orders
GROUP BY DAYNAME(DeliveryDate)
ORDER BY OrderCount DESC;

# Question 2
# Print ProductId, ProductName, Sub-Category for of those Products 
# which are having no Sub Category 
# and fill 'No_sub_category' in that place.
# Sort the order in ascending order of ProductId.

SELECT 
    ProductID,
    Product as ProductName,
    COALESCE(NULLIF(Sub_Category, ''), 'No_sub_category') as Sub_Category
FROM products
ORDER BY ProductID;

# OR
SELECT 
    ProductID,
    Product as ProductName,
    IFNULL(NULLIF(Sub_Category, ''), 'No_sub_category') as Sub_Category
FROM products
ORDER BY ProductID;

# Question 3
# Write a query to find the average revenue for each order 
# whose difference between the order date and ship date is 3.
# Use the total order amount to calculate the revenue. 
# Print the order ID, customer ID, average revenue, 
# and sort them in increasing order of the order ID.

SELECT 
    OrderID,
    CustomerID,
    AVG(Total_order_amount) as Average_Revenue
FROM orders 
WHERE DATEDIFF(ShipDate, OrderDate) = 3
GROUP BY OrderID, CustomerID
ORDER BY OrderID ASC;

# Question 4
# A Customers who born earlier than or 1980 (included) they known as Gen X, 
# a customers who born between 1981 and 1996 both included they known as Millennials 
# and Customers who born after 1996 they known as Gen Z . 
# Print all these generations name and total discounts avail by them 
# and sort the table on generation name. 
# Discount meaning here price difference between sell price and market price.

WITH CustomerGenerations AS (
    SELECT 
        c.CustomerID,
        CASE 
            WHEN YEAR(c.Date_of_Birth) <= 1980 THEN 'Gen X'
            WHEN YEAR(c.Date_of_Birth) BETWEEN 1981 AND 1996 THEN 'Millennials'
            ELSE 'Gen Z'
        END AS Generation,
        o.OrderID,
        od.ProductID,
        (p.Market_Price - p.Sale_Price) * od.Quantity as Discount
    FROM customers c
    JOIN orders o ON c.CustomerID = o.CustomerID
    JOIN orderdetails od ON o.OrderID = od.OrderID
    JOIN products p ON od.ProductID = p.ProductID
)
SELECT 
    Generation,
    SUM(Discount) as Total_Discount
FROM CustomerGenerations
GROUP BY Generation
ORDER BY Generation;

# Question 5
# Find out the Supplier Country to Customer Country distribution of delivery lagtime.
# Delivery lagtime can be calculated as difference between OrderDate and ShipDate
# Convert the Delivery lagtime in buckets as less than or equal to 3, 
# less than or equal to 5, less than or equal to 7 and greater than 7
# Final output should contain SupplierCountry, CustomerCountry, 
# bucket less than or equal to 3, less than or equal to 5, 
# less than or equal to 7 and greater than 7 in seperate columns.
# Sort the output by First by greater than 7 in descending order, 
# less than or equal to 7 in desc, less than or equal to 5 in desc, less than or equal to 3 in desc. 
# Then sort it by CustomerCountry and SupplierCountry in alphabetical order. 
# Limit your output to 10 rows

WITH OrderLagTime AS (
    SELECT 
        s.Country as SupplierCountry,
        c.Country as CustomerCountry,
        DATEDIFF(o.ShipDate, o.OrderDate) as delivery_lag
    FROM orders o
    JOIN orderdetails od ON o.OrderID = od.OrderID
    JOIN suppliers s ON od.SupplierID = s.SupplierID
    JOIN customers c ON o.CustomerID = c.CustomerID
),
LagBuckets AS (
    SELECT 
        SupplierCountry,
        CustomerCountry,
        SUM(CASE WHEN delivery_lag <= 3 THEN 1 ELSE 0 END) as 'less_equal_3',
        SUM(CASE WHEN delivery_lag > 3 AND delivery_lag <= 5 THEN 1 ELSE 0 END) as 'less_equal_5',
        SUM(CASE WHEN delivery_lag > 5 AND delivery_lag <= 7 THEN 1 ELSE 0 END) as 'less_equal_7',
        SUM(CASE WHEN delivery_lag > 7 THEN 1 ELSE 0 END) as 'greater_7'
    FROM OrderLagTime
    GROUP BY SupplierCountry, CustomerCountry
)
SELECT *
FROM LagBuckets
ORDER BY 
    greater_7 DESC,
    less_equal_7 DESC,
    less_equal_5 DESC,
    less_equal_3 DESC,
    CustomerCountry ASC,
    SupplierCountry ASC
LIMIT 10;

# Question 6
# Count the number of Suppliers based out of each Country.
# Print the following sentence:
# For Example : 
# if the number of suppliers are more than 1 then print 
# 'There are 100 Suppliers from France' 
# else print 'There is 1 Supplier from France'
# Order the output in ascending order of country.
# Note: All characters are case sensitive.
# Table/s -> Suppliers

SELECT 
    CASE 
        WHEN COUNT(*) > 1 THEN CONCAT('There are ', COUNT(*), ' Suppliers from ', Country)
        ELSE CONCAT('There is ', COUNT(*), ' Supplier from ', Country)
    END as supplier_count
FROM suppliers
GROUP BY Country
ORDER BY Country ASC;

# Question 7
# The stakeholders want to know the average number of days a customer takes to order for the year 2021.
# In here, if customer ordered multiple times in a single day then that date will be counted only once 
# and next order will be considered for the next unique day customer ordered.
# If the decimal value(.07 in 65.07) in the avg number of days is above 0.5 then get the ceil of the average, 
# if it is below 0.5 (included), then get the floor of the value.
# Print Customer Id, First Name, Last Name, Average number of days they take to order.
# Sort the output in ascending order of Customer Id.

WITH UniqueOrderDates AS (
    -- Get unique order dates for each customer
    SELECT DISTINCT 
        CustomerID,
        OrderDate
    FROM orders 
    WHERE YEAR(OrderDate) = 2021
),
DateDiffs AS (
    -- Calculate days between consecutive orders using LAG
    SELECT 
        CustomerID,
        DATEDIFF(OrderDate, 
            LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate)
        ) as days_between_orders
    FROM UniqueOrderDates
),
AvgDays AS (
    -- Calculate average days between orders
    SELECT 
        CustomerID,
        AVG(days_between_orders) as avg_days
    FROM DateDiffs
    WHERE days_between_orders IS NOT NULL
    GROUP BY CustomerID
)
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    CASE 
        WHEN (avg_days - FLOOR(avg_days)) > 0.5 THEN CEIL(avg_days)
        ELSE FLOOR(avg_days)
    END as average_days_to_order
FROM customers c
LEFT JOIN AvgDays a ON c.CustomerID = a.CustomerID
ORDER BY c.CustomerID ASC;

# Question 8
# The stakeholders wants to know about the Products 
# which were ordered in 2021 but not in 2020.
# Print unique Product Id and Product Name of those products.
# Sort the output in increasing order of Product Id.

SELECT DISTINCT 
    p.ProductID,
    p.Product as ProductName
FROM products p
JOIN orderdetails od ON p.ProductID = od.ProductID
JOIN orders o ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2021
AND p.ProductID NOT IN (
    SELECT DISTINCT od2.ProductID
    FROM orderdetails od2
    JOIN orders o2 ON od2.OrderID = o2.OrderID
    WHERE YEAR(o2.OrderDate) = 2020
)
ORDER BY p.ProductID ASC;

# Question 9
# Print Customer Id, Full Name(FirstName LastName), Postal Code
# Sort the output in decreasing order Customer Id.

SELECT 
    CustomerID,
    CONCAT(FirstName, ' ', LastName) as FullName,
    PostalCode
FROM customers
ORDER BY CustomerID DESC;

# Question 10
# Get the Description of customer along with the Customerid and Domain of their email
# For customer with no lastname take "Web" as their last name.
# The Final output should contain this columns Customerid, Domain of their email, Description.
# Get the details of description from the below attached sample output Description_ column.
# Sort the result by DateEntered desc, if date entered is same then CustomerId in ascending.
# Description Sample -
# Malcom Julian was born on 8th March 1985 has ordered 12 orders yet.
# Note- All letters are case sensetive take same case letters as given in sample output Description_. 
# Every Day value will have 'th' in front of it

SELECT 
    c.CustomerID,
    SUBSTRING_INDEX(c.Email, '@', -1) as EmailDomain,
    CONCAT(
        c.FirstName, ' ',
        COALESCE(c.LastName, 'Web'),
        ' was born on ',
        DAY(c.Date_of_Birth), 'th ',
        MONTHNAME(c.Date_of_Birth), ' ',
        YEAR(c.Date_of_Birth),
        ' has ordered ',
        COUNT(o.OrderID),
        ' orders yet.'
    ) as Description
FROM customers c
LEFT JOIN orders o ON c.CustomerID = o.CustomerID
GROUP BY 
    c.CustomerID,
    c.Email,
    c.FirstName,
    c.LastName,
    c.Date_of_Birth,
    c.DateEntered
ORDER BY 
    c.DateEntered DESC,
    c.CustomerID ASC;
INSERT INTO Dim_Brands(brand_id, brand_name)
SELECT brand_id, brand_name
FROM read_csv_auto('{brands_csv}', nullstr='NULL');

INSERT INTO Dim_Categories(category_id, category_name)
SELECT category_id, category_name
FROM read_csv_auto('{categories_csv}', nullstr='NULL');

INSERT INTO Dim_Customers(customer_id, first_name, last_name, phone, email, street, city, state, zipcode)
SELECT customer_id, first_name, last_name, phone, email, street, city, state, zip_code
FROM read_csv_auto('{customers_csv}', nullstr='NULL');

INSERT INTO Dim_Stores(store_id, store_name, phone, email, street, city, state, zipcode)
SELECT store_id, store_name, phone, email, street, city, state, zip_code
FROM read_csv_auto('{stores_csv}', nullstr='NULL');

INSERT INTO Dim_Staffs (staff_id, first_name, last_name, email, phone, active)
SELECT staff_id, first_name, last_name, email, phone, active
FROM read_csv_auto('{staffs_csv}', nullstr='NULL');

INSERT INTO Dim_Products(product_id, product_name, model_year, list_price)
SELECT product_id, product_name, model_year, list_price
FROM read_csv_auto('{products_csv}', nullstr='NULL');

INSERT INTO Dim_Orders(order_id, order_status, required_date, shipped_date)
SELECT order_id, order_status, required_date, shipped_date
FROM read_csv_auto('{orders_csv}', nullstr='NULL');

INSERT INTO Dim_Dates (date_id, date, year, quarter, month, day)
SELECT
    ROW_NUMBER() OVER (ORDER BY date) AS date_id,
    date,
    EXTRACT(year FROM date) AS year,
    EXTRACT(quarter FROM date) AS quarter,
    CASE EXTRACT(month FROM date)
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS month,
    EXTRACT(day FROM date) AS day
FROM (
    SELECT DISTINCT order_date AS date
    FROM read_csv_auto('{orders_csv}', nullstr='NULL')
) AS distinct_dates;

INSERT INTO Fact_Sales
SELECT
    oi.order_id,
    oi.product_id,
    p.brand_id,
    p.category_id,
    o.customer_id,
    o.store_id,
    o.staff_id,
    d.date_id,
    p.list_price * (1 - oi.discount) * oi.quantity AS final_price
FROM read_csv_auto('{order_items_csv}', nullstr='NULL') oi
JOIN read_csv_auto('{orders_csv}', nullstr='NULL') o ON oi.order_id = o.order_id
JOIN read_csv_auto('{products_csv}', nullstr='NULL') p ON oi.product_id = p.product_id
JOIN Dim_Dates d ON o.order_date = d.date
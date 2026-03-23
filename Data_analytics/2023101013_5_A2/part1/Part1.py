import duckdb

# Paths to your CSV files
brands_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/brands.csv'
categories_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/categories.csv'
customers_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/customers.csv'
order_items_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/order_items.csv'
orders_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/orders.csv'
products_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/products.csv'
staffs_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/staffs.csv'
stocks_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/stocks.csv'
stores_csv = 'M25 Data Analytics I Assignment-2/M25_DA_A2_Part1/stores.csv'

# Connect to DuckDB
conn = duckdb.connect('DA_A2_P1.db')

#-----------------------------------------------------
# Task 1: Create Database Schema
#-----------------------------------------------------

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Brands (
    brand_id INTEGER PRIMARY KEY,
    brand_name VARCHAR
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Categories (
    category_id INTEGER PRIMARY KEY,
    category_name VARCHAR
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Customers (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    street VARCHAR,
    city VARCHAR,
    state VARCHAR,
    zipcode INTEGER
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Stores (
    store_id INTEGER PRIMARY KEY,
    store_name VARCHAR,
    phone VARCHAR,
    email VARCHAR,
    street VARCHAR,
    city VARCHAR,
    state VARCHAR,
    zipcode INTEGER
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Staffs (
    staff_id INTEGER PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    active INTEGER,
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR,
    model_year INTEGER,
    list_price DECIMAL
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Orders (
    order_id INTEGER PRIMARY KEY,
    order_status INTEGER,
    required_date DATE,
    shipped_date DATE,
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Dim_Dates (
    date_id INTEGER PRIMARY KEY,
    date DATE,
    day INTEGER,
    month VARCHAR,
    quarter INTEGER,
    year INTEGER
);
''')

conn.execute('''
CREATE TABLE IF NOT EXISTS Fact_Sales (
    order_id INTEGER,
    product_id INTEGER,
    brand_id INTEGER,
    category_id INTEGER,
    customer_id INTEGER,
    store_id INTEGER,
    staff_id INTEGER,
    date_id INTEGER,
    final_price DECIMAL,
    FOREIGN KEY (order_id) REFERENCES Dim_Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Dim_Products(product_id),
    FOREIGN KEY (brand_id) REFERENCES Dim_Brands(brand_id),
    FOREIGN KEY (category_id) REFERENCES Dim_Categories(category_id),
    FOREIGN KEY (customer_id) REFERENCES Dim_Customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES Dim_Stores(store_id),
    FOREIGN KEY (staff_id) REFERENCES Dim_Staffs(staff_id),
    FOREIGN KEY (date_id) REFERENCES Dim_Dates(date_id)
);
''')

print("\n Tables created successfully.")

#-----------------------------------------------------
# Task 2: Data Loading
#-----------------------------------------------------

# Load data into dimension tables explicitly specifying columns

conn.execute(f'''
INSERT INTO Dim_Brands(brand_id, brand_name)
SELECT brand_id, brand_name
FROM read_csv_auto('{brands_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Categories(category_id, category_name)
SELECT category_id, category_name
FROM read_csv_auto('{categories_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Customers(customer_id, first_name, last_name, phone, email, street, city, state, zipcode)
SELECT customer_id, first_name, last_name, phone, email, street, city, state, zip_code
FROM read_csv_auto('{customers_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Stores(store_id, store_name, phone, email, street, city, state, zipcode)
SELECT store_id, store_name, phone, email, street, city, state, zip_code
FROM read_csv_auto('{stores_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Staffs (staff_id, first_name, last_name, email, phone, active)
SELECT staff_id, first_name, last_name, email, phone, active
FROM read_csv_auto('{staffs_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Products(product_id, product_name, model_year, list_price)
SELECT product_id, product_name, model_year, list_price
FROM read_csv_auto('{products_csv}', nullstr='NULL');
''')

conn.execute(f'''
INSERT INTO Dim_Orders(order_id, order_status, required_date, shipped_date)
SELECT order_id, order_status, required_date, shipped_date
FROM read_csv_auto('{orders_csv}', nullstr='NULL');
''')

conn.execute(f'''
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
''')

print("\n Dimension tables loaded successfully.")

# Populate Fact_Sales
fact_sales_query = f'''
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
'''

conn.execute(fact_sales_query)

print("\n Fact_Sales table populated successfully.")

#Preview some sample data
# print("\nSample from Dim_Dates:")
# print(conn.execute("SELECT * FROM Dim_Dates LIMIT 5").fetchdf())

# print("\nSample from Fact_Sales:")
# print(conn.execute("SELECT * FROM Fact_Sales LIMIT 5").fetchdf())

#-----------------------------------------------------
# Task 3: Queries & OLAP Analysis
#-----------------------------------------------------

# 1. Total Revenue Drill-down (Year → Quarter → Month)
conn.execute('''
COPY (
    SELECT
        d.year,
        d.quarter,
        d.month AS month_name,
        SUM(f.final_price) AS total_revenue
    FROM Fact_Sales f
    JOIN Dim_Dates d ON f.date_id = d.date_id
    GROUP BY ROLLUP (d.year, d.quarter, d.month)
    ORDER BY d.year, d.quarter, d.month
) TO 'query1_total_revenue.csv' WITH (FORMAT CSV, HEADER);
''')

# 2. Month with Highest Sales Per Year
conn.execute('''
COPY (
    SELECT year, month_name, total_revenue FROM (
        SELECT
            d.year,
            d.month AS month_name,
            SUM(f.final_price) AS total_revenue,
            ROW_NUMBER() OVER (PARTITION BY d.year ORDER BY SUM(f.final_price) DESC) AS rn
        FROM Fact_Sales f
        JOIN Dim_Dates d ON f.date_id = d.date_id
        GROUP BY d.year, d.month
    ) WHERE rn = 1
) TO 'query2_highest_sales_month.csv' WITH (FORMAT CSV, HEADER);
''')

# 3. Revenue by Category Using GROUPING SETS
conn.execute('''
COPY (
    SELECT
        f.category_id,
        c.category_name,
        SUM(f.final_price) AS total_revenue
    FROM Fact_Sales f
    JOIN Dim_Categories c ON f.category_id = c.category_id
    GROUP BY GROUPING SETS ((f.category_id, c.category_name), ())
    ORDER BY total_revenue DESC
) TO 'query3_revenue_by_category.csv' WITH (FORMAT CSV, HEADER);
''')

# 4. Drill-down from Category → Product
conn.execute('''
COPY (
    SELECT
        f.category_id,
        c.category_name,
        f.product_id,
        p.product_name,
        SUM(f.final_price) AS revenue
    FROM Fact_Sales f
    JOIN Dim_Categories c ON f.category_id = c.category_id
    JOIN Dim_Products p ON f.product_id = p.product_id
    GROUP BY f.category_id, c.category_name, f.product_id, p.product_name
    ORDER BY f.category_id, revenue DESC
) TO 'query4_category_product.csv' WITH (FORMAT CSV, HEADER);
''')

# 5. Cube: Sales by Brand, Category, Year
conn.execute('''
COPY (
    SELECT
    b.brand_name,
    c.category_name,
    d.year,
    SUM(f.final_price) AS total_revenue
    FROM Fact_Sales f
    JOIN Dim_Brands b ON f.brand_id = b.brand_id
    JOIN Dim_Categories c ON f.category_id = c.category_id
    JOIN Dim_Dates d ON f.date_id = d.date_id
    GROUP BY CUBE (b.brand_name, c.category_name, d.year)
    ORDER BY d.year, b.brand_name, c.category_name
) TO 'query5_cube_brand_category_year.csv' (HEADER, DELIMITER ',');
''')

# 6. Top 5 Customers by Total Purchase Amount
conn.execute('''
COPY (
    SELECT
        f.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.city,
        c.state,
        SUM(f.final_price) AS total_spent
    FROM Fact_Sales f
    JOIN Dim_Customers c ON f.customer_id = c.customer_id
    GROUP BY f.customer_id, customer_name, c.city, c.state
    ORDER BY total_spent DESC
    LIMIT 5
) TO 'query6_top_customers.csv' WITH (FORMAT CSV, HEADER);
''')

# 7. Staff Members Generating Highest Sales Per Store
conn.execute('''
COPY (
    SELECT store_id, store_name, staff_id, staff_name, total_revenue FROM (
        SELECT
            f.store_id,
            s.store_name,
            f.staff_id,
            st.first_name || ' ' || st.last_name AS staff_name,
            SUM(f.final_price) AS total_revenue,
            ROW_NUMBER() OVER (PARTITION BY f.store_id ORDER BY SUM(f.final_price) DESC) AS rn
        FROM Fact_Sales f
        JOIN Dim_Stores s ON f.store_id = s.store_id
        JOIN Dim_Staffs st ON f.staff_id = st.staff_id
        GROUP BY f.store_id, s.store_name, f.staff_id, staff_name
    ) WHERE rn = 1
    ORDER BY store_id
) TO 'query7_top_staff_per_store.csv' WITH (FORMAT CSV, HEADER);
''')

# 8. Cube: Sales by Category, Store, Year
conn.execute('''
COPY (
    SELECT
    c.category_name,
    s.store_name,
    d.year,
    SUM(f.final_price) AS total_revenue
    FROM Fact_Sales f
    JOIN Dim_Categories c ON f.category_id = c.category_id
    JOIN Dim_Stores s ON f.store_id = s.store_id
    JOIN Dim_Dates d ON f.date_id = d.date_id
    GROUP BY CUBE (c.category_name, s.store_name, d.year)
    ORDER BY c.category_name, s.store_name, d.year
) TO 'query8_cube_category_store_year.csv' (HEADER, DELIMITER ',');
''')

print("All queries exported successfully to CSV files.")





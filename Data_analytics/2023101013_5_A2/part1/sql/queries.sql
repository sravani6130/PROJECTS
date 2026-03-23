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


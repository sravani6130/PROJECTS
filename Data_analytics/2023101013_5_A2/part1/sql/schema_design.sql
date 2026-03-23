CREATE TABLE IF NOT EXISTS Dim_Brands (
    brand_id INTEGER PRIMARY KEY,
    brand_name VARCHAR
);

CREATE TABLE IF NOT EXISTS Dim_Categories (
    category_id INTEGER PRIMARY KEY,
    category_name VARCHAR
);

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

CREATE TABLE IF NOT EXISTS Dim_Staffs (
    staff_id INTEGER PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    active INTEGER,
);

CREATE TABLE IF NOT EXISTS Dim_Products (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR,
    model_year INTEGER,
    list_price DECIMAL
);

CREATE TABLE IF NOT EXISTS Dim_Orders (
    order_id INTEGER PRIMARY KEY,
    order_status INTEGER,
    required_date DATE,
    shipped_date DATE,
);

CREATE TABLE IF NOT EXISTS Dim_Dates (
    date_id INTEGER PRIMARY KEY,
    date DATE,
    day INTEGER,
    month VARCHAR,
    quarter INTEGER,
    year INTEGER
);

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


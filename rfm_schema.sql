CREATE DATABASE rfm_analysis;
USE rfm_analysis;

SHOW VARIABLES LIKE 'secure_file_priv';

ALTER DATABASE rfm_analysis
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS online_retail;

CREATE TABLE online_retail (
    invoice_no    VARCHAR(20),
    stock_code    VARCHAR(50),
    description   TEXT,
    quantity      INT,
    invoice_date  VARCHAR(50),
    unit_price    DECIMAL(10,2),
    customer_id   VARCHAR(50),
    country       VARCHAR(50)
)
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_2009_2010_utf8.csv'
INTO TABLE online_retail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_2010_2011_utf8.csv'
INTO TABLE online_retail
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM online_retail;

SELECT description
FROM online_retail
WHERE description LIKE '%Gift%'
LIMIT 5;

SELECT COUNT(*) AS total_rows
FROM online_retail;

SELECT COUNT(*) AS null_customers
FROM online_retail
WHERE customer_id IS NULL OR customer_id = '';

SELECT COUNT(*) AS cancellations
FROM online_retail
WHERE invoice_no LIKE 'C%';

CREATE TABLE online_retail_no_cancel AS
SELECT *
FROM online_retail
WHERE invoice_no NOT LIKE 'C%';

SELECT COUNT(*) FROM online_retail_no_cancel;

CREATE TABLE online_retail_clean AS
SELECT *
FROM online_retail_no_cancel
WHERE customer_id IS NOT NULL
  AND customer_id <> '';
  
SELECT COUNT(*) FROM online_retail_clean;

ALTER TABLE online_retail_clean
ADD COLUMN invoice_datetime DATETIME;

UPDATE online_retail_clean
SET invoice_datetime =
STR_TO_DATE(invoice_date, '%d-%m-%Y %H:%i');

SELECT invoice_date, invoice_datetime
FROM online_retail_clean
LIMIT 5;

ALTER TABLE online_retail_clean
ADD COLUMN sales DECIMAL(12,2);

UPDATE online_retail_clean
SET sales = quantity * unit_price;

SELECT quantity, unit_price, sales
FROM online_retail_clean
LIMIT 5;

DELETE FROM online_retail_clean
WHERE quantity <= 0
   OR unit_price <= 0;
   
SELECT COUNT(*) FROM online_retail_clean;



SELECT MAX(invoice_datetime) FROM online_retail_clean;

CREATE TABLE rfm_base AS
SELECT
    customer_id,

    -- Recency: days since last purchase
    DATEDIFF('2011-12-10', MAX(invoice_datetime)) AS recency,

    -- Frequency: number of unique invoices
    COUNT(DISTINCT invoice_no) AS frequency,

    -- Monetary: total spend
    SUM(sales) AS monetary

FROM online_retail_clean
GROUP BY customer_id;

SELECT * FROM rfm_base
LIMIT 10;

SELECT MIN(recency), MAX(recency) FROM rfm_base;
SELECT MIN(frequency), MAX(frequency) FROM rfm_base;
SELECT MIN(monetary), MAX(monetary) FROM rfm_base;


CREATE TABLE rfm_scores AS
SELECT
    customer_id,
    recency,
    frequency,
    monetary,

    -- Recency score: lower recency = higher score
    NTILE(5) OVER (ORDER BY recency DESC) AS r_score,

    -- Frequency score: higher frequency = higher score
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,

    -- Monetary score: higher spend = higher score
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score

FROM rfm_base;

SELECT *
FROM rfm_scores
LIMIT 10;

ALTER TABLE rfm_scores
ADD COLUMN rfm_score VARCHAR(10);

UPDATE rfm_scores
SET rfm_score = CONCAT(r_score, f_score, m_score);

SELECT r_score, COUNT(*) FROM rfm_scores GROUP BY r_score;
SELECT f_score, COUNT(*) FROM rfm_scores GROUP BY f_score;
SELECT m_score, COUNT(*) FROM rfm_scores GROUP BY m_score;


ALTER TABLE rfm_scores
ADD COLUMN customer_segment VARCHAR(50);

UPDATE rfm_scores
SET customer_segment =
CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
        THEN 'High-Value Customers'

    WHEN f_score >= 4 AND m_score >= 3
        THEN 'Loyal Customers'

    WHEN r_score >= 4 AND f_score <= 3
        THEN 'Potential Loyalists'

    WHEN r_score <= 2 AND f_score >= 3
        THEN 'At-Risk Customers'

    WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
        THEN 'Lost Customers'

    ELSE 'Others'
END;

SELECT customer_segment, COUNT(*) AS customers
FROM rfm_scores
GROUP BY customer_segment;

SELECT
    customer_id,
    r_score,
    f_score,
    m_score,
    rfm_score,
    customer_segment,
    monetary
FROM rfm_scores;



DROP TABLE IF EXISTS rfm_scores;

CREATE TABLE rfm_scores AS
SELECT
    customer_id,
    recency,
    frequency,
    monetary,

    -- Recency: lower is better → reverse order
    NTILE(5) OVER (ORDER BY recency DESC) AS r_score,

    -- Frequency: higher is better
    NTILE(5) OVER (ORDER BY frequency) AS f_score,

    -- Monetary: higher is better
    NTILE(5) OVER (ORDER BY monetary) AS m_score

FROM rfm_base;

SELECT m_score, COUNT(*) 
FROM rfm_scores
GROUP BY m_score
ORDER BY m_score;

ALTER TABLE rfm_scores
ADD COLUMN rfm_score VARCHAR(10);

UPDATE rfm_scores
SET rfm_score = CONCAT(r_score, f_score, m_score);

SELECT r_score, f_score, m_score, rfm_score
FROM rfm_scores
LIMIT 10;

ALTER TABLE rfm_scores
ADD COLUMN customer_segment VARCHAR(50);

UPDATE rfm_scores
SET customer_segment =
CASE
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'High-Value Customers'
    WHEN f_score >= 4 AND r_score >= 3 THEN 'Loyal Customers'
    WHEN r_score >= 4 AND f_score <= 2 THEN 'Potential Loyalists'
    WHEN r_score <= 2 AND f_score >= 3 THEN 'At-Risk Customers'
    ELSE 'Lost Customers'
END;

SELECT customer_segment, COUNT(*)
FROM rfm_scores
GROUP BY customer_segment;




SELECT
    customer_id,
    r_score,
    f_score,
    m_score,
    rfm_score,
    customer_segment,
    monetary
FROM rfm_scores;




UPDATE rfm_scores rs
JOIN (
    SELECT
        customer_id,
        NTILE(5) OVER (ORDER BY monetary DESC) AS new_m_score
    FROM rfm_scores
) t
ON rs.customer_id = t.customer_id
SET rs.m_score = t.new_m_score;

UPDATE rfm_scores
SET rfm_score = CONCAT(r_score, f_score, m_score);

SELECT m_score, COUNT(*)
FROM rfm_scores
GROUP BY m_score
ORDER BY m_score;

SELECT
    customer_id,
    r_score,
    f_score,
    m_score,
    rfm_score,
    customer_segment,
    monetary
FROM rfm_scores;

UPDATE rfm_scores rs
JOIN (
  SELECT customer_id,
         NTILE(5) OVER (ORDER BY monetary) AS new_m_score
  FROM rfm_scores
) t
ON rs.customer_id = t.customer_id
SET rs.m_score = t.new_m_score;

UPDATE rfm_scores
SET rfm_score = CONCAT(r_score, f_score, m_score);

SELECT m_score, COUNT(*)
FROM rfm_scores
GROUP BY m_score
ORDER BY m_score;

SELECT
  customer_id,
  r_score,
  f_score,
  m_score,
  rfm_score,
  customer_segment,
  monetary
FROM rfm_scores;

SELECT customer_id, monetary, m_score
FROM rfm_scores
ORDER BY monetary DESC
LIMIT 20;






























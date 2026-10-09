EXEC sp_rename 'dbo.olist_orders_dataset',          'orders';
EXEC sp_rename 'dbo.olist_order_items_dataset',     'order_items';
EXEC sp_rename 'dbo.olist_customers_dataset',       'customers';
EXEC sp_rename 'dbo.olist_order_payments_dataset',  'payments';
EXEC sp_rename 'dbo.olist_order_reviews_dataset',   'reviews';
EXEC sp_rename 'dbo.olist_products_dataset',        'products';
EXEC sp_rename 'dbo.olist_sellers_dataset',         'sellers';
EXEC sp_rename 'dbo.product_category_name_translation', 'category_translation';

SELECT 'orders' AS t, COUNT(*) AS n FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'customers', COUNT(*) FROM dbo.customers
UNION ALL SELECT 'payments', COUNT(*) FROM dbo.payments
UNION ALL SELECT 'reviews', COUNT(*) FROM dbo.reviews
UNION ALL SELECT 'products', COUNT(*) FROM dbo.products
UNION ALL SELECT 'sellers', COUNT(*) FROM dbo.sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM dbo.category_translation;

SELECT TOP 5 * FROM dbo.orders;

CREATE OR ALTER VIEW dbo.order_summary AS
WITH it AS (
    SELECT order_id, COUNT(*) AS items,
           SUM(price) AS item_revenue, SUM(freight_value) AS freight
    FROM dbo.order_items GROUP BY order_id
),
pay AS (
    SELECT order_id, SUM(payment_value) AS paid
    FROM dbo.payments GROUP BY order_id
),
rv AS (
    SELECT order_id, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_creation_date DESC, review_id) AS rn
    FROM dbo.reviews
)
SELECT o.order_id, c.customer_unique_id, c.customer_state, o.order_status,
       CAST(o.order_purchase_timestamp AS DATE) AS order_date,
       DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
                     MONTH(o.order_purchase_timestamp), 1) AS order_month,
       it.items, it.item_revenue, it.freight, pay.paid, rv.review_score,
       DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            WHEN CAST(o.order_delivered_customer_date AS DATE)
               > CAST(o.order_estimated_delivery_date AS DATE) THEN 1
            ELSE 0 END AS is_late
FROM dbo.orders o
JOIN dbo.customers c ON c.customer_id = o.customer_id
LEFT JOIN it  ON it.order_id  = o.order_id
LEFT JOIN pay ON pay.order_id = o.order_id
LEFT JOIN rv  ON rv.order_id  = o.order_id AND rv.rn = 1;

-- One row per order? Both numbers should be 99,441
SELECT COUNT(*) AS rows_in_view, COUNT(DISTINCT order_id) AS distinct_orders
FROM dbo.order_summary;

-- Order statuses
SELECT order_status, COUNT(*) AS orders
FROM dbo.order_summary GROUP BY order_status ORDER BY orders DESC;

-- The fan-out trap: same revenue, two answers
SELECT SUM(i.price) AS naive_join_revenue
FROM dbo.order_items i JOIN dbo.payments p ON p.order_id = i.order_id;

SELECT SUM(price) AS true_item_revenue FROM dbo.order_items;

--- monthly orders and revenue, with growth
WITH m AS (
    SELECT order_month,
           COUNT(*) AS orders,
           SUM(item_revenue) AS revenue
    FROM dbo.order_summary
    WHERE order_status NOT IN ('canceled','unavailable')
    GROUP BY order_month
)
SELECT order_month, orders, ROUND(revenue, 0) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
             / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 1) AS revenue_growth_pct
FROM m
ORDER BY order_month;

SELECT TOP 3 * FROM dbo.category_translation;

EXEC sp_rename 'dbo.category_translation.column1', 'product_category_name', 'COLUMN';
EXEC sp_rename 'dbo.category_translation.column2', 'product_category_name_english', 'COLUMN';

DELETE FROM dbo.category_translation
WHERE product_category_name = 'product_category_name';


SELECT COUNT(*) AS n FROM dbo.category_translation;       
SELECT TOP 3 * FROM dbo.category_translation;               

-- Top categories by revenue
SELECT TOP 15
       COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT i.order_id) AS orders,
       ROUND(SUM(i.price), 0) AS revenue,
       ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 1) AS pct_of_revenue,
       ROUND(AVG(i.price), 0) AS avg_item_price
FROM dbo.order_items i
JOIN dbo.orders o ON o.order_id = i.order_id
LEFT JOIN dbo.products p ON p.product_id = i.product_id
LEFT JOIN dbo.category_translation t ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled','unavailable')
GROUP BY COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
ORDER BY revenue DESC;

-- Revenue by customer state
SELECT TOP 10 customer_state,
       COUNT(*) AS orders,
       ROUND(SUM(item_revenue), 0) AS revenue,
       ROUND(100.0 * SUM(item_revenue) / SUM(SUM(item_revenue)) OVER (), 1) AS pct_of_revenue,
       ROUND(AVG(item_revenue), 0) AS avg_order_value
FROM dbo.order_summary
WHERE order_status NOT IN ('canceled','unavailable')
GROUP BY customer_state
ORDER BY revenue DESC;

-- Does late delivery hurt review scores? (delivered orders only)
SELECT is_late,
       COUNT(*) AS orders,
       ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS avg_review,
       ROUND(100.0 * AVG(CASE WHEN review_score = 1 THEN 1.0 ELSE 0 END), 1) AS pct_1_star,
       ROUND(100.0 * AVG(CASE WHEN review_score = 5 THEN 1.0 ELSE 0 END), 1) AS pct_5_star
FROM dbo.order_summary
WHERE order_status = 'delivered' AND is_late IS NOT NULL AND review_score IS NOT NULL
GROUP BY is_late;

-- Repeat customers (uses customer_unique_id, not customer_id)
WITH c AS (
    SELECT customer_unique_id, COUNT(*) AS orders, SUM(item_revenue) AS rev
    FROM dbo.order_summary
    WHERE order_status NOT IN ('canceled','unavailable')
    GROUP BY customer_unique_id
)
SELECT CASE WHEN orders = 1 THEN '1 order'
            WHEN orders = 2 THEN '2 orders' ELSE '3+ orders' END AS segment,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers,
       ROUND(SUM(rev), 0) AS revenue,
       ROUND(100.0 * SUM(rev) / SUM(SUM(rev)) OVER (), 1) AS pct_of_revenue
FROM c
GROUP BY CASE WHEN orders = 1 THEN '1 order'
              WHEN orders = 2 THEN '2 orders' ELSE '3+ orders' END
ORDER BY MIN(orders);

-- Payment methods
SELECT payment_type,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(payment_value), 0) AS paid,
       ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 1) AS pct_of_value,
       ROUND(AVG(payment_value), 0) AS avg_payment,
       ROUND(AVG(CAST(payment_installments AS FLOAT)), 1) AS avg_installments
FROM dbo.payments
GROUP BY payment_type
ORDER BY paid DESC;

-- Seller concentration
WITH s AS (
    SELECT i.seller_id, SUM(i.price) AS revenue
    FROM dbo.order_items i
    JOIN dbo.orders o ON o.order_id = i.order_id
    WHERE o.order_status NOT IN ('canceled','unavailable')
    GROUP BY i.seller_id
),
r AS (
    SELECT revenue,
           ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rk,
           COUNT(*) OVER () AS n,
           SUM(revenue) OVER () AS total
    FROM s
)
SELECT CASE WHEN rk <= n * 0.01 THEN 'Top 1% of sellers'
            WHEN rk <= n * 0.10 THEN 'Next 9% (top 10%)'
            ELSE 'Remaining 90%' END AS seller_group,
       COUNT(*) AS sellers,
       ROUND(SUM(revenue), 0) AS revenue,
       ROUND(100.0 * SUM(revenue) / MAX(total), 1) AS pct_of_revenue
FROM r
GROUP BY CASE WHEN rk <= n * 0.01 THEN 'Top 1% of sellers'
              WHEN rk <= n * 0.10 THEN 'Next 9% (top 10%)'
              ELSE 'Remaining 90%' END
ORDER BY MIN(rk);
-------
CREATE OR ALTER VIEW dbo.category_sales AS
SELECT i.order_id, i.order_item_id, i.seller_id, i.price, i.freight_value,
       COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category
FROM dbo.order_items i
LEFT JOIN dbo.products p ON p.product_id = i.product_id
LEFT JOIN dbo.category_translation t ON t.product_category_name = p.product_category_name;
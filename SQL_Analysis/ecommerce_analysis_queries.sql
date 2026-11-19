/*
Project: E-commerce Business Performance & Customer Analytics
Database: ecommerce_analytics
Engine: MySQL 8.0
Dataset: Brazilian e-commerce public dataset (Olist-style)

Important metric definitions:
- Sales = SUM(order_items.price); excludes freight and includes all order statuses.
- AOV = item-price sales / distinct orders with at least one item.
- Delivered rate = delivered orders / all orders in the dataset.
- Repeat customer = customer_unique_id with more than one distinct order.
- Delivery comparisons use calendar dates and delivered orders with valid
  purchase, delivered, and estimated delivery dates.
- Avoid joining order_items directly to payments/reviews in one raw join:
  one order can have multiple item, payment, or review rows, which can inflate
  totals. Aggregate to order-level first when combining these tables.
*/

USE ecommerce_analytics;

-- 01. Table row counts (run each SELECT separately if your client does not
-- display multiple result sets).
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders;
SELECT 'order_items' AS table_name, COUNT(*) AS row_count FROM order_items;
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers;
SELECT 'products' AS table_name, COUNT(*) AS row_count FROM products;
SELECT 'payments' AS table_name, COUNT(*) AS row_count FROM payments;
SELECT 'reviews' AS table_name, COUNT(*) AS row_count FROM reviews;
SELECT 'sellers' AS table_name, COUNT(*) AS row_count FROM sellers;
SELECT 'category_translation' AS table_name, COUNT(*) AS row_count FROM category_translation;

-- 02. Order status distribution
SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) AS pct_all_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 03. Overall sales and AOV. Sales excludes freight and includes all statuses.
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END) AS delivered_orders,
    ROUND(
      100.0 * COUNT(DISTINCT CASE WHEN o.order_status = 'delivered' THEN o.order_id END)
      / COUNT(DISTINCT o.order_id), 2
    ) AS delivered_order_rate_pct,
    COUNT(DISTINCT oi.order_id) AS orders_with_items,
    COUNT(oi.order_id) AS order_item_rows,
    ROUND(SUM(oi.price), 2) AS sales_value_brl_excluding_freight,
    ROUND(SUM(oi.price) / COUNT(DISTINCT oi.order_id), 2) AS average_order_value_brl
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id;

-- 04. Monthly sales trend
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month,
    COUNT(DISTINCT o.order_id) AS orders_with_items,
    ROUND(SUM(oi.price), 2) AS sales_brl,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS average_order_value_brl
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY purchase_month;

-- 05. Top 10 product categories by item-price sales
-- Handles category translation gaps and carriage-return/missing values.
SELECT
    COALESCE(
      NULLIF(TRIM(ct.product_category_name_english), ''),
      NULLIF(TRIM(p.product_category_name), ''),
      'Unknown'
    ) AS category,
    COUNT(DISTINCT oi.order_id) AS orders,
    COUNT(*) AS items,
    ROUND(SUM(oi.price), 2) AS sales_brl,
    ROUND(AVG(oi.price), 2) AS average_item_price_brl
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON TRIM(TRAILING '\r' FROM p.product_category_name) = TRIM(TRAILING '\r' FROM ct.product_category_name)
GROUP BY category
ORDER BY sales_brl DESC
LIMIT 10;

-- 06. Repeat-customer analysis using customer_unique_id
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS unique_customers,
    SUM(order_count = 1) AS one_time_customers,
    SUM(order_count > 1) AS repeat_customers,
    ROUND(100.0 * SUM(order_count > 1) / COUNT(*), 2) AS repeat_customer_pct,
    SUM(CASE WHEN order_count > 1 THEN order_count ELSE 0 END) AS orders_from_repeat_customers
FROM customer_order_counts;

-- 07. Delivery performance (calendar days; delivered orders only)
SELECT
    COUNT(*) AS eligible_delivered_orders,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2)
        AS avg_calendar_delivery_days,
    ROUND(100.0 * AVG(
        DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) <= 0
    ), 2) AS delivered_on_or_before_estimate_pct,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date)), 2)
        AS avg_days_vs_estimate
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- 08. Overall review-score distribution
SELECT
    review_score,
    COUNT(*) AS review_rows,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM reviews), 2) AS pct_review_rows
FROM reviews
WHERE review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

SELECT
    COUNT(*) AS review_rows_with_score,
    ROUND(AVG(review_score), 2) AS average_review_score,
    SUM(review_score IN (1,2)) AS low_rating_rows,
    ROUND(100.0 * AVG(review_score IN (1,2)), 2) AS low_rating_pct
FROM reviews
WHERE review_score IS NOT NULL;

-- 09. Delivery timing vs review rating.
-- First reduce reviews to one row per order to avoid duplicated review rows.
-- This keeps the latest review_creation_date when available.
WITH ranked_reviews AS (
    SELECT
        order_id,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_creation_date DESC, review_id DESC
        ) AS rn
    FROM reviews
    WHERE review_score IS NOT NULL
),
delivery_groups AS (
    SELECT
        order_id,
        CASE
          WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
            THEN 'Delivered Late'
          ELSE 'On Time or Early'
        END AS delivery_group
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    d.delivery_group,
    COUNT(DISTINCT d.order_id) AS reviewed_orders,
    ROUND(AVG(r.review_score), 2) AS average_rating,
    SUM(r.review_score IN (1,2)) AS low_rating_count,
    ROUND(100.0 * AVG(r.review_score IN (1,2)), 2) AS low_rating_pct
FROM delivery_groups d
JOIN ranked_reviews r ON d.order_id = r.order_id AND r.rn = 1
GROUP BY d.delivery_group
ORDER BY d.delivery_group;

-- 10. Review scores by product category (aggregate to order/category before
-- joining reviews to avoid multiplying reviews for multi-item orders).
WITH order_category AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(
          NULLIF(TRIM(ct.product_category_name_english), ''),
          NULLIF(TRIM(p.product_category_name), ''),
          'Unknown'
        ) AS category
    FROM order_items oi
    LEFT JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
      ON TRIM(TRAILING '\r' FROM p.product_category_name) = TRIM(TRAILING '\r' FROM ct.product_category_name)
),
order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS review_score
    FROM reviews
    WHERE review_score IS NOT NULL
    GROUP BY order_id
)
SELECT
    oc.category,
    COUNT(DISTINCT oc.order_id) AS orders,
    COUNT(orv.order_id) AS reviewed_orders,
    ROUND(AVG(orv.review_score), 2) AS average_review_score,
    ROUND(100.0 * AVG(orv.review_score IN (1,2)), 2) AS low_rating_pct
FROM order_category oc
JOIN order_reviews orv ON oc.order_id = orv.order_id
GROUP BY oc.category
ORDER BY average_review_score ASC, reviewed_orders DESC;

-- 11. Product data-quality checks
SELECT
    COUNT(*) AS product_rows,
    SUM(product_category_name IS NULL OR TRIM(product_category_name) = '') AS missing_category_rows
FROM products;

SELECT
    COUNT(DISTINCT p.product_id) AS products_with_category,
    COUNT(DISTINCT CASE
      WHEN NULLIF(TRIM(ct.product_category_name_english), '') IS NOT NULL
      THEN p.product_id END) AS products_with_english_translation
FROM products p
LEFT JOIN category_translation ct
  ON TRIM(TRAILING '\r' FROM p.product_category_name) = TRIM(TRAILING '\r' FROM ct.product_category_name)
WHERE p.product_category_name IS NOT NULL
  AND TRIM(p.product_category_name) <> '';

-- 12. Check duplicate order IDs in reviews
SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT order_id) AS distinct_orders_with_reviews,
    COUNT(*) - COUNT(DISTINCT order_id) AS extra_rows_beyond_one_per_order
FROM reviews
WHERE order_id IS NOT NULL;

-- Notes:
-- * No reliable product cost/discount field is part of this core dataset, so
--   do not report profit or discount-margin metrics from these tables.
-- * Some months at the beginning/end of the dataset are partial; compare
--   complete months carefully.
-- * Low repeat purchase rate is a lead for further investigation, not proof
--   of customer dissatisfaction.

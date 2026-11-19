SQL deliverables package
========================

1. Open ecommerce_analysis_queries.sql in MySQL Workbench or run statements in the MySQL command-line client.
2. Confirm the database is named ecommerce_analytics and table names match:
   orders, order_items, customers, products, payments, reviews, sellers,
   category_translation.
3. Run each SELECT statement and export its result grid to CSV if you need the full result tables.
4. The Query_Results folder contains selected results reconstructed from findings already established in the project. It does not pretend to contain every historical SQL result.
5. Read SQL_Analysis_Summary.md for KPI definitions, results, caveats, and business interpretations.

Important:
- Sales sum order_items.price, excluding freight, and include all order statuses.
- Don't join raw order_items, payments and reviews all at once without aggregation.
- Some results may differ slightly if the current MySQL database has changed or if duplicate reviews are handled differently. Use the query output from your current database as the source of truth before publishing.

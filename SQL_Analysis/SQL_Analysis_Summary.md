# SQL Analysis Summary
## E-commerce Business Performance & Customer Analytics

**Database:** `ecommerce_analytics` (MySQL 8.0)  
**Dataset period:** 4 September 2016 to 17 October 2018  
**Sales definition:** Sum of item `price` in BRL; freight excluded; all order statuses included.

## Validated headline KPIs

| KPI | Result |
|---|---:|
| Total orders | 99,441 |
| Delivered orders | 96,478 |
| Delivered order rate | 97.02% |
| Canceled orders | 625 (0.63%) |
| Orders with items | 98,666 |
| Order-item rows | 112,650 |
| Sales value (BRL, excluding freight) | R$13,591,643.70 |
| Average order value (BRL) | R$137.75 |
| Unique customers (`customer_unique_id`) | 96,096 |
| One-time customers | 93,099 (96.88%) |
| Repeat customers | 2,997 (3.12%) |
| Orders from repeat customers | 6,342 |
| Average review score | 4.09 / 5 |
| Low reviews (1–2 stars) | 14.69% |

## Business findings

### Sales trend
- Sales peaked in November 2017 at **R$1,010,271.37** across **7,451 orders**.
- January 2018 had the highest monthly order count in the previously reviewed trend: **7,220 orders**.
- March–May 2018 sales were each approximately R$983K–R$997K.
- The dataset has partial months at the edges; do not compare those directly with full months.

### Top categories by sales
| Category | Orders | Items | Sales (BRL) | Average item price (BRL) |
|---|---:|---:|---:|---:|
| health_beauty | 8,836 | 9,670 | 1,258,681.34 | 130.16 |
| watches_gifts | 5,624 | 5,991 | 1,205,005.68 | 201.14 |
| bed_bath_table | 9,417 | 11,115 | 1,036,988.68 | 93.30 |
| sports_leisure | 7,720 | 8,641 | 988,048.97 | 114.34 |
| computers_accessories | 6,689 | 7,827 | 911,954.32 | 116.51 |
| furniture_decor | 6,449 | 8,334 | 729,762.49 | 87.56 |
| cool_stuff | 3,632 | 3,796 | 635,290.85 | 167.36 |
| housewares | 5,884 | 6,964 | 632,248.66 | 90.79 |
| auto | 3,897 | 4,235 | 592,720.11 | 139.96 |
| garden_tools | 3,518 | 4,347 | 485,256.46 | 111.63 |

### Delivery performance
- Among delivered orders with valid purchase, delivered, and estimated dates: **96,470** eligible.
- Average calendar delivery time: **12.50 days**.
- Delivered on or before estimated date: **93.23%**.
- Average actual calendar delivery date relative to estimate: **11.88 days earlier**.
- In the latest Python one-review-per-order analysis, reviewed late orders had an average score of **2.27/5**, while on-time/early reviewed orders averaged **4.29/5**.
- Low ratings were **62.40%** of reviewed late orders versus **9.27%** of reviewed on-time/early orders.
- Treat this as an association, not proof that delivery delays caused low ratings.

### Review scores
| Score | Count |
|---:|---:|
| 1 | 11,424 |
| 2 | 3,151 |
| 3 | 8,179 |
| 4 | 19,142 |
| 5 | 57,328 |
- The latest raw CSV check counted 99,224 review rows. An earlier SQL check returned 99,223, so rerun the review count query and use the current database output consistently in the final report.
- Average review score: 4.09/5; 14.69% of review rows have scores 1 or 2.

### Product and data-quality notes
- Products table: 32,951 rows; 610 product rows have missing category values.
- Product category translation has 71 rows after trimming carriage-return characters.
- Earlier check: 32,341 products had a category; 32,328 had an English translation.
- Review/order relationships can contain multiple review rows per order. For delivery-rating analysis, reduce to one review per order using a clearly stated rule.
- Do not directly join raw order items, payments, and reviews together without aggregating first; this can multiply rows and inflate measures.
- This dataset does not provide a dependable product cost field for profit calculation. Avoid claiming profit, margin, or discount profitability from the core tables.
- Other non-delivered order statuses include in-progress states; do not label every non-delivered order as failed.

## Recommended actions / investigation leads
1. Investigate late-delivery causes by seller, geography, and purchase month.
2. Explore retention cohorts and customer repeat behavior; the 3.12% repeat rate is observed only within this dataset period.
3. Review categories with lower ratings and ensure sample sizes are considered.
4. Monitor cancellations and unavailable orders separately from intermediate statuses.
5. Define sales and order-level measures carefully before building the Power BI model.

## Files
- `ecommerce_analysis_queries.sql`: rerunnable SQL analysis queries.
- `Query_Results/`: selected known results from the earlier analysis.
- `KPI_Summary.csv`: headline KPI summary.
- `README.txt`: instructions for using these files.

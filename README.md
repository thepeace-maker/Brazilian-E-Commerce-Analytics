# Olist E-commerce: Where Growth Came From and What to Do Next 🛒

## 1. Problem

Olist is a Brazilian marketplace that connects small sellers to customers. Between 2017 and mid-2018 its order volume grew fast, but growth that depends on constantly finding new customers is expensive. **The question for management:** where did the growth come from, what is hurting customer satisfaction, and where should the team act first?

[Dashboard]


 <img width="874" height="492" alt="Dashboard Image" src="https://github.com/user-attachments/assets/d5a39ef0-f35b-46dd-8dfe-c4f1ad7f1764" />

## 2. Analysis

- **Data:** "Brazilian E-Commerce Public Dataset by Olist" (Kaggle, olistbr): 99,441 orders across 8 related tables, 2016-2018.
- **Dashboard window:** Jan 2017 to Aug 2018, with canceled and unavailable orders excluded (97,910 orders). The 2016 months have too few orders to analyse, and the single September 2018 order is dropped.
- **Tools:** SQL Server (SSMS) for cleaning and joins, Power BI for the data model and dashboard.
- **SQL techniques:** multi-table joins, CTEs, window functions (`LAG`, `ROW_NUMBER`, share of total), and one row per order built *before* joining.
- **Data-quality catch:** joining order items to payments overstated revenue by 4.5% (14.21M vs 13.59M), because orders with several payment rows were counted more than once. Every query aggregates each table to one row per order first.
- **Other cleaning:** some orders have more than one review, so the latest review is kept. Customers are identified by `customer_unique_id`, because `customer_id` changes with every order. Product categories were translated from Portuguese with the translation table.
- **A note on numbers:** the dashboard covers Jan 2017 to Aug 2018. The SQL scripts for categories, states, reviews, repeat customers and sellers cover the whole dataset (canceled and unavailable orders excluded), so a few figures differ by small amounts (for example repeat customers: 97.0% in SQL, 96.95% on the dashboard).

## 3. Insights

1. **Growth came from new customers, not loyalty.** Monthly orders rose from 787 (Jan 2017) to a peak of 7,423 (Nov 2017), then plateaued at roughly 6,100 to 7,200 a month through Aug 2018. About 97% of customers bought only once, and they brought in 94.4% of revenue.
2. **Late delivery goes with very low reviews.** About 6.7% of delivered orders arrived after the estimated date. Those orders averaged **2.27 stars against 4.29** for on-time orders, and 53.8% of them got a 1-star review (6.6% for on-time orders). This is an association, not proof of cause.
3. **Revenue is concentrated.** São Paulo is 38.3% of revenue and the top 3 states (SP, RJ, MG) are 63.4%. The top 10% of sellers (305 of 3,053 active sellers) earn 67.5% of revenue. Average order value is similar across states (126 to 152), so state differences come from order volume.
4. **Categories differ in what they earn per order.** Health & beauty leads revenue (9.3%). Watches & gifts is second (8.9%) from far fewer orders, because its average item price is about 201, against 93 for bed, bath & table.
5. **Payments are mostly credit cards:** 78.3% of payment value, with about 3.5 installments on average, and boleto (bank slip) second at 17.9%.

## 4. Recommendations

| # | Recommendation | Evidence | How to measure it |
|---|---|---|---|
| 1 | **Fix late delivery first.** Audit the carriers and routes behind late orders, and set estimated delivery dates the operation can meet. | Late orders score 2.27 vs 4.29 stars. Best case, if late orders scored like on-time ones, the average review would rise by about 0.13 points. | Late rate and share of 1-star reviews, monthly |
| 2 | **Test a post-delivery repeat-purchase campaign** aimed at customers who gave 4 or 5 stars. | About 97% buy once. A two-order customer is worth about 246 in item revenue, against 138 for a one-order customer. | Repeat rate (3.04% today), test group vs control |
| 3 | **Promote high-ticket categories** such as watches & gifts, and test bundles. | About 201 average item price vs 93 in the largest-volume categories. | Revenue per order, by category |
| 4 | **Protect the top sellers.** Assign account support to the top 10% of sellers and watch for churn. | 305 sellers produce 67.5% of revenue. | Share of revenue from top sellers, and their retention |

**Next analysis:** check whether delivery times and late rates explain the low order volume outside São Paulo before recommending geographic expansion.

## 5. Limitations

1. Revenue is item price in Brazilian reais, excluding freight. Payment value is a larger, separate figure, and orders can use more than one payment method.
2. "Late" means later than the estimated delivery date. The link between lateness and review scores is an association, not proof of cause.
3. The window is short, so repeat-purchase rates may be understated for customers who joined late.
4. The 2016 months, the single September 2018 order, and the missing November 2016 are excluded or noted.
5. Recommendation sizes are estimates for prioritising, not forecasts.

## 6. Dashboard

Cards for orders, revenue, late rate and repeat-customer rate; top categories by share of revenue; average review by delivery status; monthly orders; revenue by state; customers by number of orders. A date slicer controls the window.

## 7. Files

| File | Purpose |
|---|---|
| `Olist Ecommerce.pbix` | Power BI report and star-schema model |
| `Ecommerce_Queries.sql` | E01 to E09: order summary view, checks, monthly trend, categories, states, reviews vs lateness, repeat customers, payments, seller concentration |
| `dashboard-images/dashboard.png` | Dashboard screenshot |

**Tools:** SQL Server (SSMS), Power BI Desktop, DAX.

## 8. Getting Started

1. Download `Olist Ecommerce.pbix` from this repository and open it in Power BI Desktop.
2. To rerun the SQL, download the dataset from Kaggle, import the 8 tables with Allow Nulls ticked, rename them (`orders`, `order_items`, `customers`, `payments`, `reviews`, `products`, `sellers`, `category_translation`), then run `Ecommerce_Queries.sql` from top to bottom.

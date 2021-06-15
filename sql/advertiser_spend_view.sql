-- Copyright 2021 Google LLC.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

WITH advertiser_latest_cost_update AS
    (SELECT Advertiser_ID AS advertiser_id, 
    MAX(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS latest_report_date,
    MIN(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS first_report_date,
    COUNT(DISTINCT Date) AS days_of_data,
    COUNT(DISTINCT Insertion_Order_ID) AS insertion_orders,
    COUNT(DISTINCT Line_Item_ID) AS line_items
    FROM `${datasetId}.dv360_spend_report_data`
    GROUP BY Advertiser_ID),

    advertiser_current_month_data_summary AS 
    (SELECT Advertiser_ID AS advertiser_id,
    Line_Item_ID AS line_item_id,
    Insertion_Order_ID AS insertion_order_id, 
    MAX(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS latest_report_date,
    MIN(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS first_report_date,
    COUNT(DISTINCT Date) AS days_of_data,
    COUNT(*) AS hours_of_data,
    FROM `${datasetId}.dv360_spend_report_data`
    WHERE EXTRACT(MONTH from Date) = EXTRACT(MONTH from CURRENT_DATE('Australia/Sydney'))
    GROUP BY Advertiser_ID, Line_Item_ID, Insertion_Order_ID),

    advertiser_spend_yesterday AS 
    (SELECT Advertiser_ID AS advertiser_id,
            ROUND(SUM(Media_Cost__Advertiser_Currency_), 2) AS daily_media_cost,
            ROUND(SUM(Revenue__Adv_Currency_), 2) AS daily_media_revenue,
            DATE_ADD(CURRENT_DATE('Australia/Sydney'), INTERVAL -1 DAY) AS date_yesterday
    FROM `${datasetId}.dv360_spend_report_data`
    WHERE Date = (DATE_ADD(CURRENT_DATE('Australia/Sydney'), INTERVAL -1 DAY))
    GROUP BY advertiser_id),

    advertiser_spend_today AS 
    (SELECT Advertiser_ID AS advertiser_id,
            ROUND(SUM(Media_Cost__Advertiser_Currency_), 2) AS daily_media_cost,
            ROUND(SUM(Revenue__Adv_Currency_), 2) AS daily_media_revenue,
            CURRENT_DATE('Australia/Sydney') AS date_today
    FROM `${datasetId}.dv360_spend_report_data`
    WHERE Date = (CURRENT_DATE('Australia/Sydney'))
    GROUP BY advertiser_id),

    advertiser_daily_media_cost AS 
    (SELECT Advertiser_ID AS advertiser_id,
            EXTRACT(MONTH from Date) AS month,
            EXTRACT(DAY from Date) AS day, 
            SUM(Media_Cost__Advertiser_Currency_) AS daily_media_cost,
            SUM(Revenue__Adv_Currency_) AS daily_media_revenue
    FROM `${datasetId}.dv360_spend_report_data`
    GROUP BY advertiser_id, month, day),

    advertiser_daily_media_cost_avg AS 
    (SELECT advertiser_id, 
            month,
            ROUND(AVG(ROUND(daily_media_cost, 2)),2) AS daily_media_cost_avg,
            ROUND(AVG(ROUND(daily_media_revenue, 2)),2) AS daily_media_revenue_avg
    FROM    advertiser_daily_media_cost 
    GROUP BY advertiser_id, month),

    advertiser_monthly_media_cost AS
    (SELECT Partner AS partner_name,
            Partner_ID AS partner_id,
            Advertiser AS advertiser_name,
            a.Advertiser_ID AS advertiser_id,
            EXTRACT(MONTH from Date) AS month,
            MAX(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS latest_report_date,
            MIN(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"))) AS first_report_date,
            COUNT(DISTINCT Date) AS days_of_data,
            line_items,
            insertion_orders,
            ROUND(SUM(Media_Cost__Advertiser_Currency_), 2) AS monthly_media_cost,
            ROUND(SUM(Revenue__Adv_Currency_), 2) AS monthly_media_revenue,
            b.daily_media_cost_avg AS daily_media_cost_avg,
            b.daily_media_revenue_avg AS daily_media_revenue_avg,
            d.daily_media_cost AS daily_media_cost_today,
            d.daily_media_revenue AS daily_media_revenue_today,
            e.daily_media_cost AS daily_media_cost_yesterday,
            e.daily_media_revenue AS daily_media_revenue_yesterday
FROM `${datasetId}.dv360_spend_report_data` a
INNER JOIN advertiser_daily_media_cost_avg b ON a.advertiser_id = b.advertiser_id AND EXTRACT(MONTH from a.Date) = b.month
INNER JOIN advertiser_latest_cost_update c ON a.advertiser_id = c.advertiser_id
INNER JOIN advertiser_spend_today d on a.advertiser_id = d.advertiser_id 
INNER JOIN advertiser_spend_yesterday e ON a.advertiser_id = e.advertiser_id 
GROUP BY 1, 2, 3, 4, 5, 9, 10, 13, 14, 15, 16, 17, 18)

SELECT  IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap) AS monthly_cap,
        config.warning_threshold AS warning_threshold,
        config.pausing_threshold AS pausing_threshold,
        advertiser_monthly_media_cost.*,
        ROUND((IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)-monthly_media_revenue),2) AS budget_remaining,
        ROUND((monthly_media_revenue/IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)),4) AS percentage_spent,
        DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY) AS days_remaining,
        CASE
            WHEN ROUND(ROUND((IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)-monthly_media_revenue),2)/DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY),2) < 0 THEN 0
            ELSE ROUND(ROUND((IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)-monthly_media_revenue),2)/DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY),2)
        END AS required_spend_rate,
        ROUND(daily_media_revenue_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY),2) AS predicted_additional_spend,
        ROUND((daily_media_revenue_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY)+monthly_media_revenue),2) AS predicted_monthly_spend,
        CASE
            WHEN ROUND((daily_media_revenue_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY)+monthly_media_revenue)-IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap),2) < 0 THEN 0
            ELSE ROUND((daily_media_revenue_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE('Australia/Sydney')), CURRENT_DATE('Australia/Sydney'), DAY)+monthly_media_revenue)-IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap),2)
        END AS predicted_overspend,
        CASE
            WHEN ROUND((IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)-monthly_media_revenue)/daily_media_revenue_avg, 2) < 0 THEN 0
            ELSE ROUND((IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)-monthly_media_revenue)/daily_media_revenue_avg, 2)
        END AS days_until_limit_exceeded,
        CASE
            WHEN ROUND((monthly_media_revenue/IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)),4)>=pausing_threshold THEN 'Spend Limit Exceeded'
            WHEN ROUND((monthly_media_revenue/IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)),4)>=warning_threshold  THEN 'Approaching Spend Limit'
            ELSE 'OK'
        END AS current_status,
        CASE
            WHEN ROUND((monthly_media_revenue/IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)),4)>=pausing_threshold THEN 'Pause Live Activity'
            WHEN ROUND((monthly_media_revenue/IFNULL(advertiser_config.advertiser_monthly_cap, config.advertiser_monthly_cap)),4)>=warning_threshold  THEN 'Send Email Warning'
            ELSE 'No action required'
        END AS next_step

FROM advertiser_monthly_media_cost
INNER JOIN `${datasetId}.dv360_spend_monitor_config` AS config USING (partner_id)
LEFT OUTER JOIN `${datasetId}.dv360_advertiser_config` AS advertiser_config USING (partner_id, advertiser_id)
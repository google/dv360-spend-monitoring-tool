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

WITH
  partner_latest_cost_update AS (
  SELECT
    Partner_ID AS partner_id,
    MAX(DATETIME(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"), Advertiser_Time_Zone), "${timezone}")) AS latest_report_date,
    MIN(DATETIME(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"), Advertiser_Time_Zone), "${timezone}")) AS first_report_date,
    IFNULL(COUNT(DISTINCT Date), 0) AS total_days_of_data,
    IFNULL(COUNT(DISTINCT Insertion_Order_ID), 0) AS insertion_orders,
    COUNT(DISTINCT Line_Item_ID) AS line_items
  FROM
    `${datasetId}.dv360_spend_report_data`
  GROUP BY
    partner_id),
  partner_spend_yesterday AS (
  SELECT
    Partner_ID AS partner_id,
    IFNULL(ROUND(SUM(Media_Cost__Advertiser_Currency_), 2), 0) AS daily_media_cost,
    IFNULL(ROUND(SUM(Revenue__Adv_Currency_), 2), 0) AS daily_media_revenue,
    DATE_ADD(CURRENT_DATE("${timezone}"), INTERVAL -1 DAY) AS date_yesterday
  FROM
    `${datasetId}.dv360_spend_report_data`
  WHERE
    Date = (DATE_ADD(CURRENT_DATE("${timezone}"), INTERVAL -1 DAY))
  GROUP BY
    partner_id),
  partner_spend_today AS (
  SELECT
    Partner_ID AS partner_id,
    IFNULL(ROUND(SUM(Media_Cost__Advertiser_Currency_), 2), 0) AS daily_media_cost,
    IFNULL(ROUND(SUM(Revenue__Adv_Currency_), 2), 0) AS daily_media_revenue,
    CURRENT_DATE("${timezone}") AS date_today
  FROM
    `${datasetId}.dv360_spend_report_data`
  WHERE
    Date = (CURRENT_DATE("${timezone}"))
  GROUP BY
    partner_id),
  partner_daily_media_cost AS (
  SELECT
    Partner_ID AS partner_id,
    EXTRACT(MONTH
    FROM
      Date) AS month,
    EXTRACT(DAY
    FROM
      Date) AS day,
    IFNULL(SUM(Media_Cost__Advertiser_Currency_), 0) AS daily_media_cost,
    IFNULL(SUM(Revenue__Adv_Currency_), 0) AS daily_media_revenue
  FROM
    `${datasetId}.dv360_spend_report_data`
  GROUP BY
    partner_id,
    month,
    day),
  partner_daily_media_cost_avg AS (
  SELECT
    partner_id,
    month,
    IFNULL(ROUND(AVG(ROUND(daily_media_cost, 2)),2), 0) AS daily_media_cost_avg,
    IFNULL(ROUND(AVG(ROUND(daily_media_revenue, 2)),2), 0) AS daily_media_revenue_avg
  FROM
    partner_daily_media_cost
  GROUP BY
    partner_id,
    month),
  partner_monthly_media_cost AS (
  SELECT
    Partner AS partner_name,
    a.Partner_ID AS partner_id,
    EXTRACT(MONTH
    FROM
      Date) AS month,
    MAX(DATETIME(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"), Advertiser_Time_Zone), "${timezone}")) AS latest_report_date,
    MIN(DATETIME(TIMESTAMP(CONCAT(Date, " ", Time_of_Day, ":00:00"), Advertiser_Time_Zone), "${timezone}")) AS first_report_date,
    COUNT(DISTINCT Date) AS monthly_days_of_data,
    total_days_of_data,
    line_items,
    insertion_orders,
    IFNULL(ROUND(SUM(Media_Cost__Advertiser_Currency_), 2), 0) AS monthly_media_cost,
    IFNULL(ROUND(SUM(Revenue__Adv_Currency_), 2), 0) AS monthly_media_revenue,
    IFNULL(b.daily_media_cost_avg, 0) AS daily_media_cost_avg,
    IFNULL(b.daily_media_revenue_avg, 0) AS daily_media_revenue_avg,
    IFNULL(d.daily_media_cost, 0) AS daily_media_cost_today,
    IFNULL(d.daily_media_revenue, 0) AS daily_media_revenue_today,
    IFNULL(e.daily_media_cost, 0) AS daily_media_cost_yesterday,
    IFNULL(e.daily_media_revenue, 0) AS daily_media_revenue_yesterday
  FROM
    `${datasetId}.dv360_spend_report_data` a
  INNER JOIN
    partner_daily_media_cost_avg b
  ON
    a.partner_id = b.partner_id
    AND EXTRACT(MONTH
    FROM
      a.Date) = b.month
  INNER JOIN
    partner_latest_cost_update c
  ON
    a.partner_id = c.partner_id
  LEFT JOIN
    partner_spend_today d
  ON
    a.partner_id = d.partner_id
  LEFT JOIN
    partner_spend_yesterday e
  ON
    a.partner_id = e.partner_id
  GROUP BY
    1,
    2,
    3,
    7,
    8,
    9,
    12,
    13,
    14,
    15,
    16,
    17)
SELECT
  config.partner_monthly_cap AS monthly_cap,
  warning1_threshold, 
  warning2_threshold,
  action1_threshold,
  action2_threshold,
  partner_monthly_media_cost.*,
  IFNULL(ROUND((config.partner_monthly_cap-monthly_media_cost),2), 0) AS budget_remaining,
  IFNULL(ROUND((monthly_media_cost/config.partner_monthly_cap),4), 0) AS percentage_spent,
  DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY) AS days_remaining,
  CASE
    WHEN ROUND(ROUND((config.partner_monthly_cap-monthly_media_cost),2)/DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY),2) < 0 THEN 0
  ELSE
  ROUND(ROUND((config.partner_monthly_cap-monthly_media_cost),2)/DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY),2)
END
  AS required_spend_rate,
  IFNULL(ROUND(daily_media_cost_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY),2), 0) AS predicted_additional_spend,
  IFNULL(ROUND((daily_media_cost_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY)+monthly_media_cost),2), 0) AS predicted_monthly_spend,
  CASE
    WHEN ROUND((daily_media_cost_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY)+monthly_media_cost)-config.partner_monthly_cap,2) < 0 THEN 0
  ELSE
  ROUND((daily_media_cost_avg*DATE_DIFF(LAST_DAY(CURRENT_DATE("${timezone}")), CURRENT_DATE("${timezone}"), DAY)+monthly_media_cost)-config.partner_monthly_cap,2)
END
  AS predicted_overspend,
  CASE
    WHEN ROUND((config.partner_monthly_cap-monthly_media_cost)/daily_media_cost_avg, 2) < 0 THEN 0
  ELSE
  ROUND((config.partner_monthly_cap-monthly_media_cost)/daily_media_cost_avg, 2)
END
  AS days_until_limit_exceeded,
  CASE
    WHEN ROUND((monthly_media_cost/config.partner_monthly_cap),4)>=warning2_threshold THEN 'Spend Limit Exceeded'
    WHEN ROUND((monthly_media_cost/config.partner_monthly_cap),4)>=warning1_threshold THEN 'Approaching Spend Limit'
  ELSE
  'OK'
END
  AS current_status,
  CASE
    WHEN ROUND((monthly_media_cost/config.partner_monthly_cap),4)>=action2_threshold THEN 'Pause Live Activity'
    WHEN ROUND((monthly_media_cost/config.partner_monthly_cap),4)>=action1_threshold THEN 'Send Email Warning'
  ELSE
  'No action required'
END
  AS next_step
FROM
  partner_monthly_media_cost
INNER JOIN
  `${datasetId}.dv360_spend_monitor_config` AS config 
USING
  (partner_id)

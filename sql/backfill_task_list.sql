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
  PARTNERS_NEED_BACKFILL AS (
  SELECT
    MIN(_PARTITIONTIME) AS partitionDay,
    Partner_ID
  FROM
    `${datasetId}.dv360_spend_report_data`
  WHERE
    DATE(_PARTITIONTIME) >= DATE_TRUNC(PARSE_DATE('%Y%m%d', '${cutoffDay}'), MONTH)
    AND DATE(_PARTITIONTIME) <= PARSE_DATE('%Y%m%d', '${cutoffDay}')
  GROUP BY
    Partner_ID
  HAVING
    DATE(partitionDay) > DATE_TRUNC(PARSE_DATE('%Y%m%d', '${cutoffDay}'), MONTH))
SELECT
  UNIX_MILLIS(TIMESTAMP(DATETIME(DATE_TRUNC(PARSE_DATE('%Y%m%d', '${cutoffDay}'), MONTH)), '${timezone}')) AS startTimeMs,
  UNIX_MILLIS(TIMESTAMP(DATETIME(PARTNERS_NEED_BACKFILL.partitionDay), '${timezone}')) - 1000 AS endTimeMs,
  FORMAT_DATE('%Y%m%d', DATE_TRUNC(PARSE_DATE('%Y%m%d', '${cutoffDay}'), MONTH)) AS partitionDay,
  report_id AS queryId
FROM
  PARTNERS_NEED_BACKFILL
INNER JOIN
  `${datasetId}.${partnerConfigTable}`
USING
  (partner_id)

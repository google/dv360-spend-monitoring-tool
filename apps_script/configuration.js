// Copyright 2019 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/** @fileoverview Configuration for this Apps Script solution. */

/** @type {!DataSheet} Partner Configuration sheet. */
const PartnerConfig = {
  sheetName: 'Partner Config',
  title: {
    fields: [
      'partner_name',
      'partner_id',
      'partner_monthly_cap',
      'advertiser_monthly_cap',
      'warning1_threshold',
      'warning2_threshold',
      'action1_threshold',
      'action2_threshold',
      'report_id',
    ],
  },
};

/** @type {!DataSheet} Advertiser Configuration sheet. */
const AdvertiserConfig = {
  sheetName: 'Advertiser Config',
  title: {
    fields: [
      'partner_name',
      'partner_id',
      'advertiser_name',
      'advertiser_id',
      'advertiser_monthly_cap',
    ],
  },
};

/** @type {string} The column name of report Id. */
const REPORT_ID = 'report_id';
/** @type {string} The column name of partner Id. */
const PARTNER_ID = 'partner_id';
/** @type {string} The column name of partner name. */
const PARTNER_NAME = 'partner_name';

/** @type {{string:string}} Map the suffix of a column name to BigQuery type. */
const FIELD_NAME_TYPE_MAPPING = {
  name: 'STRING',
  id: 'INTEGER',
  cap: 'FLOAT',
  threshold: 'FLOAT',
};

/** @type {{string:string}} Map the suffix of a column name to Sheet format. */
const FIELD_NAME_FORMAT_MAPPING = {
  threshold: '#0.00%',
};

/**
 * @typedef {{
 *   metadata: {
 *     dataRange: string,
 *     title: string,
 *   },
 *   params: {
 *     type: string,
 *     groupBys: !Array<string>,
 *     options: {
 *       includeOnlyTargetedUserLists: boolean,
 *     },
 *     filters: Array<{type: string, value: string}>,
 *     metrics: !Array<string>,
 *   }
 * }}
 */
let Dv360ReportConfiguration;

/**
 * The definition of DV360 report.
 * @type {!Dv360ReportConfiguration}
 */
const DV360_REPORT_DEFINITION = {
  params: {
    type: 'TYPE_GENERAL',
    groupBys: [
      "FILTER_PARTNER_NAME",
      "FILTER_PARTNER",
      "FILTER_ADVERTISER_NAME",
      "FILTER_ADVERTISER",
      "FILTER_ADVERTISER_CURRENCY",
      "FILTER_INSERTION_ORDER_NAME",
      "FILTER_INSERTION_ORDER",
      "FILTER_LINE_ITEM_NAME",
      "FILTER_LINE_ITEM",
      "FILTER_DATE",
      "FILTER_TIME_OF_DAY",
      "FILTER_ADVERTISER_TIMEZONE",
    ],
    filters: [
      {type: 'FILTER_PARTNER', value: '${partnerId}', }
    ],
    metrics: [
      'METRIC_IMPRESSIONS',
      'METRIC_BILLABLE_IMPRESSIONS',
      'METRIC_REVENUE_ADVERTISER',
      'METRIC_MEDIA_COST_ADVERTISER',
    ],
    options: {
      includeOnlyTargetedUserLists: false,
    }
  },
  metadata: {
    title: 'DV360 Spend Report ${partnerName}',
    dataRange: 'PREVIOUS_DAY',
  }
};

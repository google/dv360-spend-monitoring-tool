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

/** @fileoverview Main file for this Apps Script solution. */

function onOpen() {
  const advertisersSubMenu = SpreadsheetApp.getUi()
    .createMenu('DV360 Spend Monitoring');
  advertisersSubMenu.addItem('Generate Dv360 reports', 'generateReports');
  advertisersSubMenu.addSeparator();
  advertisersSubMenu.addItem('Initialize configuration sheets', 'initialize');
  advertisersSubMenu.addItem('Update external tables in BigQuery',
    'createExternalTable');
  advertisersSubMenu.addToUi();
}

/** Generates Dv360 reports for those partners without one. */
function generateReports() {
  const ui = SpreadsheetApp.getUi();
  const partnerSheet = new EnhancedSheet(PartnerConfig.sheetName);
  if (partnerSheet.sheet.getLastRow() <= 1) {
    ui.alert('Notification', 'There is no partner.', ui.ButtonSet.OK);
    return;
  }
  const partners = partnerSheet.loadModuleToArray(PartnerConfig.title);
  const missingReports = [];
  const missingPartnerRows = [];
  partners.forEach((report, index) => {
    if (!report[REPORT_ID]) {
      missingReports.push(report);
      missingPartnerRows.push(index);
    }
  });
  if (missingReports.length === 0) {
    ui.alert('Notification', 'All partners have the reports.', ui.ButtonSet.OK);
    return;
  }
  const dfa = new DoubleclickBidManager();
  const reportIds = missingReports.map((partner) => {
    const report = replaceParameters(JSON.stringify(DV360_REPORT_DEFINITION),
      {
        partnerId: partner[PARTNER_ID],
        partnerName: partner[PARTNER_NAME],
      }, true);
    return dfa.createQuery(JSON.parse(report));
  })
  reportIds.forEach((reportId, index) => {
    const startRow = missingPartnerRows[index] + 2;
    const startColumn = PartnerConfig.title.fields.indexOf(REPORT_ID) + 1;
    partnerSheet.save([[reportId]], startRow, startColumn);
  });
}

/**
 * Initialized the configuration sheet.
 */
function initialize() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  const existSheet = spreadsheet.getSheetByName(PartnerConfig.sheetName)
    || spreadsheet.getSheetByName(AdvertiserConfig.sheetName);
  if (existSheet) {
    const ui = SpreadsheetApp.getUi();
    const response = ui.alert('Please confirm',
      'This will erase everything on the Partner or Advertiser Config sheet, '
      + 'Continue?',
      ui.ButtonSet.YES_NO);
    if (response !== ui.Button.YES) {
      return;
    }
  }
  [PartnerConfig, AdvertiserConfig].forEach(configSheet => {
    const sheet = new EnhancedSheet(configSheet.sheetName);
    sheet.clear();
    sheet.save([configSheet.title.fields]);
    setFormat(configSheet.title.fields, sheet.sheet);
  });
  // Create external table in BigQuery if it's not existent.
  createExternalTable(false);
}

/**
 * Sets the format of columns in the Google Sheet.
 * @param {!Array<string>} fields Sheet column names.
 * @param {!Sheet} sheet Google Sheet
 */
function setFormat(fields, sheet) {
  return fields.map((field, index) => {
    const suffix = field.substring(field.lastIndexOf('_') + 1);
    const format = FIELD_NAME_FORMAT_MAPPING[suffix];
    if (format) {
      const column = String.fromCharCode('A'.charCodeAt(0) + index);
      sheet.getRange(column + '2:' + column).setNumberFormat(format);
    }
  });
}

/**
 * Creates or updates this Sheets as the external table in BigQuery.
 * @param {boolean=} updateIfExist Update external if exists. Default is true.
 *     To reduce the manual steps, after DV360 reports are generated, this will
 *     be called to create external table if it's not existent.
 * @param {string} skipLeadingRows The number of rows at the top of a sheet that
 *     BigQuery will skip when reading the data.
 */
function createExternalTable(updateIfExist = true, skipLeadingRows = '1') {
  const sheetUrl = SpreadsheetApp.getActiveSpreadsheet().getUrl();
  const partnerTable = {
    type: 'EXTERNAL',
    tableReference: {tableId: GCP_CONFIG.EXTERNAL_PARTNER_TABLE},
    externalDataConfiguration: {
      sourceUris: [sheetUrl],
      sourceFormat: 'GOOGLE_SHEETS',
      schema: {fields: getSchema(PartnerConfig.title.fields)},
      googleSheetsOptions: {
        skipLeadingRows,
        range: PartnerConfig.sheetName,
      },
    },
  };
  const advertiserTable = {
    type: 'EXTERNAL',
    tableReference: {tableId: GCP_CONFIG.EXTERNAL_ADVERTISER_TABLE},
    externalDataConfiguration: {
      sourceUris: [sheetUrl],
      sourceFormat: 'GOOGLE_SHEETS',
      schema: {fields: getSchema(AdvertiserConfig.title.fields)},
      googleSheetsOptions: {
        skipLeadingRows,
        range: AdvertiserConfig.sheetName,
      },
    },
  };
  const bigquery = new BigQuery(GCP_CONFIG.PROJECT_ID, GCP_CONFIG.DATASET);
  [partnerTable, advertiserTable].forEach((tableConfig) => {
    const tableId = tableConfig.tableReference.tableId;
    try {
      bigquery.getTable(tableId);
      if (updateIfExist) {
        bigquery.updateTable(tableId, tableConfig);
      }
    } catch (e) {
      bigquery.createTable(tableConfig);
    }
  });

}

/**
 * Gets the BigQuery schema from the Google Sheet column names.
 * @param {!Array<string>} fields Sheet column names.
 * @return {!Array<{name:string, type:string}>}
 */
function getSchema(fields) {
  return fields.map((field) => {
    const suffix = field.substring(field.lastIndexOf('_') + 1);
    return {
      name: field,
      type: FIELD_NAME_TYPE_MAPPING[suffix],
    };
  });
}

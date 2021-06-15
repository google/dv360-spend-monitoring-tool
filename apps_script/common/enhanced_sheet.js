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

/**
 * @typedef {{
 *   sheetName:string,
 *   title:{
 *     names:!Array<string>,
 *     fields:!Array<string>,
 *   },
 * }}
 */
let DataSheet;

/**
 * @typedef {{
 *   fields:!Array<string>,
 *   idProperty:string|undefined,
 *   startLine:number|undefined,
 * }}
 */
let DataSheetOptions;

/**
 * @fileoverview An enhanced sheet class contain utilities functions for Google
 * Spreadsheet base on @link {SpreadsheetApp}.
 */
const EnhancedSheet = class {

  constructor(sheetName, spreadsheet = SpreadsheetApp.getActiveSpreadsheet()) {
    this.sheetName = sheetName;
    this.spreadsheet = spreadsheet;
    this.initialize();
  }

  initialize() {
    this.sheet = this.spreadsheet.getSheetByName(this.sheetName);
    if (!this.sheet) {
      this.sheet = this.spreadsheet.insertSheet(this.sheetName);
    }
  }

  clear() {
    this.sheet.clear();
    this.sheet.getCharts().forEach(
        (chart) => void this.sheet.removeChart(chart));
  }

  /**
   * Saves the data to the given position.
   * @param {Array<Array<string|number>>} data
   * @param {number=} startRow, index starts at 1.
   * @param {number=} startColumn, index starts at 1.
   */
  save(data, startRow = 1, startColumn = 1) {
    this.sheet.getRange(startRow, startColumn, data.length, data[0].length)
        .setValues(data);
  }

  /**
   * Loads configuration from a Google Spreadsheet into an array.
   * @param {!DataSheetOptions} options
   * @return {!Array<Object>}
   */
  loadModuleToArray(options) {
    return this.loadModule_(options, this.loadToArray_);
  }

  /**
   * Loads configuration from a Google Spreadsheet into a map.
   * For the key in map, there must be a field acts as "id".
   * @param {!DataSheetOptions} options
   * @return {Object<string, Object>} the map contains all objects in the sheet.
   */
  loadModuleToMap(options) {
    const idProperty = options.idProperty ? options.idProperty : 'id';
    return this.loadModule_(options, this.getLoadToMapFunction_(idProperty));
  }

  /**
   * Loads the data from Spreadsheet and invoke convertor function to handle it.
   * @param {!DataSheetOptions} options
   * @param {Object} convertor the function to handle data in Spreadsheet.
   * @return {Object}
   * @private
   */
  loadModule_(options, convertor) {
    const fields = options.fields;
    const startLine = options.startLine || 2;
    const rows = this.sheet
        .getRange(startLine, 1, this.sheet.getLastRow() - startLine + 1,
            fields.length)
        .getDisplayValues();
    return convertor(rows, fields);
  }

  /**
   * Converts each row in to an object with the given fields as keys.
   * @param {!Array<!Array<string>>} rows
   * @param {!Array<string>} fields The keys for the generated objects.
   * @return {!Array<Object>}
   * @private
   */
  loadToArray_(rows, fields) {
    return rows.map((row) => {
      const item = {};
      fields.forEach((key, index) => void (item[key] = row[index]));
      return item;
    });
  }

  getLoadToMapFunction_(idProperty) {
    /**
     * Converts each row in to an object with the given fields as keys.
     * Creates a map to contain all the objects and use the field "id" as the
     * key to index them.
     * @param {!Array<!Array<string>>} rows
     * @param {!Array<string>} fields The keys for the generated objects.
     * @return {!Map<string, Object>}
     */
    return (rows, fields) => {
      const items = {};
      rows.forEach((row) => {
        const item = {};
        fields.forEach((key, index) => void (item[key] = row[index]));
        const id = item[idProperty];
        if (!id) {
          console.error(`There is no 'id' detected in the fields. Quit`);
          return;
        } else {
          if (items[id]) {
            console.log(
                `Warning: Duplicated id(${id}) detected in the fields.` +
                ' The previous one will be overwritten.');
          }
          items[id] = item;
        }
      });
      return items;
    };
  }
};

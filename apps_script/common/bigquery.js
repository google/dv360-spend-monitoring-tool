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

/** @fileoverview BigQuery API handler class.*/

class BigQuery extends ApiBase {

  constructor(projectId, datasetId) {
    super();
    this.apiUrl = 'https://bigquery.googleapis.com/bigquery';
    this.version = 'v2';
    this.projectId = projectId;
    this.datasetId = datasetId;
  }

  /** @override */
  getBaseUrl() {
    return `${this.apiUrl}/${this.version}/projects/${this.projectId}/`
        + `datasets/${this.datasetId}`;
  }

  /**
   * Gets a BigQuery table.
   * @param {string} tableId
   * @return {!Table} See:
   *     https://cloud.google.com/bigquery/docs/reference/rest/v2/tables#Table
   */
  getTable(tableId) {
    return this.get(`tables/${tableId}`);
  }

  /**
   * Creates a BigQuery table.
   * @param {!Table} config See:
   *     https://cloud.google.com/bigquery/docs/reference/rest/v2/tables#Table
   * @return {!Table}
   */
  createTable(config) {
    const response = this.mutate(`tables`, config);
    return response;
  }

  /**
   * Updates a BigQuery table.
   * @param {string} tableId
   * @param {!Table} config See:
   *     https://cloud.google.com/bigquery/docs/reference/rest/v2/tables#Table
   * @return {!Table}
   */
  updateTable(tableId, config) {
    const response = this.mutate(`tables/${tableId}`, config, 'put');
    return response;
  }
}

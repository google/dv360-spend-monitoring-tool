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

/** @fileoverview Dv360 report API handler class. */

class DoubleclickBidManager extends ApiBase {

  constructor() {
    super();
    this.apiUrl = 'https://doubleclickbidmanager.googleapis.com/doubleclickbidmanager';
    this.version = 'v1.1';
  }

  /** @override */
  getBaseUrl() {
    return `${this.apiUrl}/${this.version}`;
  }

  /**
   * Gets a Dv360 report definition.
   * @param queryId
   * @return {!Dv360ReportConfiguration}
   */
  getQuery(queryId) {
    return this.get(`query/${queryId}`);
  }

  /**
   * Creates a Dv360 report and returns the Id.
   * @param {!Dv360ReportConfiguration} report
   * @return {number} The created query Id.
   */
  createQuery(report) {
    const response = this.mutate('query', report);
    return response.queryId;
  }
}
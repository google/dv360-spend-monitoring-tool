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

/** @fileoverview REST API base class. */

/**
 * This class contains basic methods to interact with general APIs using the
 * @link {UrlFetchApp} and @link {ScriptApp} classes.
 * The recommended way is to consume the API if it is available as 'Advanced
 * Google Service' within Apps Script's 'Resources' section. However if the
 * required API is not  available, this class is used to cover that.
 *
 * @abstract
 */
class ApiBase {

  /**
   * Returns the base Url of the Api request.
   * @return {string}
   * @abstract
   */
  getBaseUrl() { }

  /**
   * Sends a HTTP GET request and retur ns the response.
   * @param {string} requestUri
   * @return {Object} Returned JSON object.
   */
  get(requestUri) {
    const url = this.buildApiUrl_(requestUri);
    const params = this.getDefaultParams_();
    params.method = 'get';
    return this.request_(url, params);
  }

  /**
   * Sends a HTTP request other than GET, e.g. POST or DELETE and returns the
   * response.
   * @param {string} requestUri
   * @param {(Object|undefined)=} payload A JSON object as the payload. Default
   *     is undefined.
   * @param {string=} method HTTP method, default is POST.
   * @return {Object} Returned JSON object.
   */
  mutate(requestUri, payload = undefined, method = 'post') {
    const url = this.buildApiUrl_(requestUri);
    const params = this.getDefaultParams_();
    params.method = method;
    if (payload) {
      params.payload = JSON.stringify(payload);
    }
    return this.request_(url, params);
  }

  /**
   * Uses UrlFetchApp to send out the HTTP request.
   * @param {string} url Request Url.
   * @param {Object} params The optional JavaScript object specifying advanced
   *   parameters. @see
   *   https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app#advanced-parameters
   * @param {boolean=} retry Whether retry if failed. Default is true.
   * @return {Object} Returned JSON object.
   * @private
   */
  request_(url, params, retry = true) {
    const response = UrlFetchApp.fetch(url, params);
    if (response.getResponseCode() / 100 !== 2) {
      throw({
        code: response.getResponseCode(),
        message: response.getContentText(),
      });
    }
    return JSON.parse(response.getContentText() || '{}');
  }

  /**
   * Constructs the fully-qualified URL to the API using the given @param
   * {requestUri}.
   *
   * @param {string} requestUri The URI of the specific resource to request.
   * @param {string=} baseUrl The API base url before specific resource.
   * @return {string} representing the fully-qualified DV360 API URL.
   * @private
   */
  buildApiUrl_(requestUri, baseUrl = this.getBaseUrl()) {
    return `${baseUrl}/${requestUri}`;
  }

  /**
   * Returns the default params for UrlFetchApp.
   * @see https://developers.google.com/apps-script/reference/url-fetch/url-fetch-app#fetch(String,Object)
   * @return {{
   *   headers: {
   *     Authorization: string,
   *     Accept: string,
   *   },
   *   contentType: string,
   * }}
   * @private
   */
  getDefaultParams_() {
    const token = ScriptApp.getOAuthToken();
    return {
      contentType: 'application/json',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
    };
  }

}

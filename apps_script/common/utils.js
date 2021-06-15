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

/** @fileoverview Utility functions. */

/**
 * Replaces a string with parameters in the pattern like `${key}`. Gets values
 * from the parameters object. Nested keys are supported.
 * @param {string} str Original string with parameters.
 * @param {!Object<string, string>} parameters
 * @param {boolean=} ignoreUnfounded Whether to ignore those properties that are
 *     not founded in the parameters . Default it throws an error if any
 *     property is not found. If set as true, it will keep parameters in
 *     original `${key}` way.
 * @return {string} Parameters replaced string.
 */
const replaceParameters = (str, parameters, ignoreUnfounded = false) => {
  const indexOfFirstPlaceholder = str.indexOf('${');
  if (indexOfFirstPlaceholder === -1) return str;
  const prefix = str.substring(0, indexOfFirstPlaceholder);
  const regex = /\${([^}]*)}/;
  const matchResult = str.match(regex);
  const splitNames = matchResult[1].split('.');
  const left = str.substring(indexOfFirstPlaceholder + matchResult[0].length);
  let value = parameters;
  for (let index in splitNames) {
    const namePiece = splitNames[index];
    if (!value || !value[namePiece]) {
      if (ignoreUnfounded) {
        value = matchResult[0];
        break;
      }
      console.error(`Fail to find property ${matchResult[1]} in parameters: `,
          parameters);
      throw new Error(`Fail to find property ${matchResult[1]} in parameter.`);
    }
    value = value[namePiece];
  }
  return prefix + value + replaceParameters(left, parameters, ignoreUnfounded);
};

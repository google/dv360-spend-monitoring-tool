#!/usr/bin/env bash
#
# Copyright 2020 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Need to get shell lib files ready before import them.
npm install

# Timezone of DV360 account
TIMEZONE="Australia/Sydney"

SOLUTION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${BASH_SOURCE[0]}" -ef "$0" ]]; then
  RELATIVE_PATH="node_modules/@google-cloud"
  source "${SOLUTION_ROOT}/${RELATIVE_PATH}/nodejs-common/bin/install_functions.sh"
  source "${SOLUTION_ROOT}/${RELATIVE_PATH}/nodejs-common/bin/bigquery.sh"
  source "${SOLUTION_ROOT}/${RELATIVE_PATH}/data-tasks-coordinator/deploy.sh"
fi

# Project namespace will be used as prefix of the name of Cloud Functions,
# Pub/Sub topics, etc.
# Default project namespace is SOLUTION_NAME.
# Note: only lowercase letters, numbers and dashes(-) are allowed.
PROJECT_NAMESPACE="probe"

# BigQuery Dataset Id.
DATASET="dv360_spend_monitor_data"
# Name of external table in BigQuery
EXTERNAL_PARTNER_TABLE="dv360_spend_monitor_config"
EXTERNAL_ADVERTISER_TABLE="dv360_advertiser_config"

# Parameter name used by functions to load and save config.
CONFIG_ITEMS=(
  "PROJECT_NAMESPACE"
  "GCS_BUCKET"
  "DATASET"
  "DATASET_LOCATION"
  "EXTERNAL_PARTNER_TABLE"
  "EXTERNAL_ADVERTISER_TABLE"
)

# DoubleClick Bid Manager API enabled in this solution for DV360 reports.
GOOGLE_CLOUD_APIS["doubleclickbidmanager.googleapis.com"]+="Google DV360 Report API"
# Google Drive API enabled in this solution for external table in BigQuery.
GOOGLE_CLOUD_APIS["drive.googleapis.com"]+="Google Drive API"

# DoubleClick Bid Manager API only supports OAuth.
ENABLED_OAUTH_SCOPES+=("https://www.googleapis.com/auth/doubleclickbidmanager")
NEED_OAUTH="true"

#######################################
# Clasp login.
# Globals:
#   None
# Arguments:
#   None
#######################################
clasp_login() {
  while :; do
    local claspLogin=$(clasp login --status)
    if [[ "${claspLogin}" != "You are not logged in." ]]; then
      printf '%s' "${claspLogin} Would you like to continue with it? [Y/n]"
      local logout
      read -r logout
      logout=${logout:-"Y"}
      if [[ ${logout} = "Y" || ${logout} = "y" ]]; then
        break
      else
        clasp logout
      fi
    fi
    clasp login --no-localhost
  done
}

#######################################
# Initialize a AppsScript project. Usually it involves following steps:
# 1. Create a AppsScript project within a new Google Sheet.
# 2. Prompt to update the Google Cloud Project number of the AppsScript project
#    to enable external APIs for this AppsScript project.
# 3. Prompt to grant the access of Cloud Functions' default service account to
#    this Google Sheet, so the Cloud Functions can query this Sheet later.
# 4. Initialize the Sheet based on requests.
# Globals:
#   None
# Arguments:
#   None
#######################################
clasp_initialize() {
  (( STEP += 1 ))
  printf '%s\n' "Step ${STEP}: Starting to create Google Sheets..."
  clasp_login
  while :; do
    local claspStatus=$(clasp status > /dev/null ;echo $?)
    if [[ $claspStatus -gt 0 ]];then
      local createdSheet=$(clasp create --type sheets --rootDir ./apps_script \
--title 'DV360 spend configuration' | grep "Created new Google Sheet: " )
      declare -g SHEET_URL="${createdSheet//Created new Google Sheet: /}"
      printf '%s\n\n' "${createdSheet}"
      break
    else
      printf '%s' "AppsScript project exists. Would you like to continue with \
it? [Y/n]"
      local useCurrent
      read -r useCurrent
      useCurrent=${useCurrent:-"Y"}
      if [[ ${useCurrent} = "Y" || ${useCurrent} = "y" ]]; then
        break
      else
        printf '%s' "Would you like to delete current AppsScript and create a \
new one? [N/y]"
        local deleteCurrent
        read -r deleteCurrent
        deleteCurrent=${deleteCurrent:-"N"}
        if [[ ${useCurrent} = "Y" || ${useCurrent} = "y" ]]; then
          echo rm ~/.clasp.json
          contine
        fi
      fi
    fi
  done
  printf '\n'
  clasp_push_codes
  clasp_update_project_number
  grant_access_to_service_account
  initialize_sheet
}

#######################################
# Copy GCP project configuration file to AppsScript codes as a constant named
# `GCP_CONFIG`.
# Globals:
#   None
# Arguments:
#   None
#######################################
generate_config_js_for_apps_script() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    echo -n "const GCP_CONFIG = " > apps_script/.generated_config.js
    cat "${CONFIG_FILE}" >> apps_script/.generated_config.js
  fi
}

#######################################
# Clasp pushes AppsScript codes.
# Globals:
#   None
# Arguments:
#   None
#######################################
clasp_push_codes() {
  (( STEP += 1 ))
  printf '%s\n' "Step ${STEP}: Starting to push codes to Google Sheets..."
  clasp status >> /dev/null
  if [[ $? -gt 0 ]]; then
    clasp_initialize
  else
    generate_config_js_for_apps_script
    clasp push --force
    printf '\n'
  fi
}

#######################################
# Ask user to update the GCP number of this AppsScript.
# Globals:
#   GCP_PROJECT
# Arguments:
#   None
#######################################
clasp_update_project_number() {
  (( STEP += 1 ))
  local projectNumber=$(gcloud projects list --filter="${GCP_PROJECT}" \
--format="value(PROJECT_NUMBER)")
  printf '%s\n' "Step ${STEP}: On the open tab of Apps Script, use 'Project \
Settings' to set the Google Cloud Platform (GCP) Project as: ${projectNumber}"
  clasp open
  printf '%s' "Press any key to continue after you update the GCP number..."
  local any
  read -n1 -s any
  printf '\n\n'
}

#######################################
# Ask user to grant the access to CF's default service account.
# Globals:
#   SHEET_URL
# Arguments:
#   None
#######################################
grant_access_to_service_account() {
  (( STEP += 1 ))
  local defaultServiceAccount=$(get_cloud_functions_service_account \
"${PROJECT_NAMESPACE}_main")
  printf '%s\n' "Step ${STEP}: Open the Google Sheet and grant the Viewer \
access to service account: ${defaultServiceAccount}"
  printf '%s\n' "Google Sheet: ${SHEET_URL}"
  printf '%s' "Press any key to continue after you grant the access..."
  local any
  read -n1 -s any
  printf '\n\n'
}

#######################################
# Guides for users to initialize Sheet.
# Globals:
#   None
# Arguments:
#   None
#######################################
initialize_sheet() {
  (( STEP += 1 ))
  printf '%s\n' "Step ${STEP}: Click menu of opened Google Sheet with the name \
[DV360 Spend Monitoring] -> [Initialize configuration sheets]"
  printf '%s' "Press any key to continue..."
  local any
  read -n1 -s any
  printf '\n\n'
  printf '%s\n' "Enter at least one partner's information in the Configuration \
Sheet (You can leave the 'Report Id' empty). Then click menu \
[DV360 Spend Monitoring] -> [Generate Dv360 reports]"
  printf '%s' "Press any key to continue..."
  local any
  read -n1 -s any
  printf '\n\n'
}

#######################################
# Create or update Cloud Scheduler jobs to trigger reports downloading.
# Globals:
#   PROJECT_NAMESPACE
#   TIMEZONE
# Arguments:
#   None
#######################################
create_or_update_scheduled_jobs() {
  (( STEP += 1 ))
  printf '%s\n' "Step ${STEP}: Starting to create or update Cloud Scheduler \
for Sentinel status check task..."
  check_authentication
  quit_if_failed $?
  create_or_update_cloud_scheduler_for_pubsub \
    "${PROJECT_NAMESPACE}_dv360_spend_report_yesterday" \
    "0 8 * * *" \
    "${TIMEZONE}" \
    ${PROJECT_NAMESPACE}-monitor \
    '{
       "timezone":"'"${TIMEZONE}"'",
       "partitionDay":"${yesterday}",
       "startTimeMs":"${yesterday_timestamp_ms}",
       "endTimeMs":"${yesterday_timestamp_ms}"
    }' \
    taskId=start_probe

  create_or_update_cloud_scheduler_for_pubsub \
    "${PROJECT_NAMESPACE}_dv360_spend_report_today" \
    "20 1-23 * * *" \
    "${TIMEZONE}" \
    ${PROJECT_NAMESPACE}-monitor \
    '{
       "timezone":"'"${TIMEZONE}"'",
       "partitionDay":"${today}",
       "startTimeMs":"${today_timestamp_ms}",
       "endTimeMs":"${today_timestamp_ms}"
    }' \
    taskId=start_probe
}

DEFAULT_INSTALL_TASKS=(
  "print_welcome Probe"
  load_config
  check_in_cloud_shell
  prepare_dependencies
  confirm_namespace confirm_project confirm_region
  check_permissions enable_apis
  create_bucket
  create_dataset
  create_sink
  save_config
  do_authentication
  deploy_cloud_functions_task_coordinator
  copy_sql_to_gcs
  check_firestore_existence
  "update_task_config ./config_task.json"
  set_internal_task
  create_or_update_scheduled_jobs
  clasp_initialize
  "print_finished Probe"
)

run_default_function "$@"

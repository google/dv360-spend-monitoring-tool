---

# This solution has been deprecated as it doesn't work with DV360 new version API.

---

# DV360 Spend Monitoring Tool

<!--* freshness: { owner: 'lushu' reviewed: '2021-06-15' } *-->

## 1. Disclaimer

Copyright 2019 Google LLC.
This is not an official Google product. This solution, including any related
sample code or data, is made available on an “as is,” “as available,” and “with
all faults” basis, solely for illustrative purposes, and without warranty or
representation of any kind. This solution is experimental, unsupported and
provided solely for your convenience. Your use of it is subject to your
agreements with Google, as applicable, and may constitute a beta feature as
defined under those agreements.  To the extent that you make any data available
to Google in connection with your use of the solution, you represent and warrant
that you have all necessary and appropriate rights, consents and permissions to
permit Google to use and process that data. By using any portion of this
solution, you acknowledge, assume and accept all risks, known and unknown,
associated with its usage, including with respect to your deployment of any
portion of this solution in your systems, or usage in connection with your
business, if at all.

## 2. Installation

### 2.1. Create/use a Google Cloud Project(GCP) with a billing account

1.  How to [Creating and Managing Projects][create_gcp]
2.  How to [Create, Modify, or Close Your Billing Account][billing_gcp]

[create_gcp]:https://cloud.google.com/resource-manager/docs/creating-managing-projects
[billing_gcp]:https://cloud.google.com/billing/docs/how-to/manage-billing-account

### 2.2. Create/use a Desktop app OAuth credential

1. How to [Setting up OAuth 2.0][setup_oauth_2.0]
2. Make sure select the Application type as 'Desktop app' 

[setup_oauth_2.0]:https://support.google.com/cloud/answer/6158849?hl=en


### 2.3. Check out source codes

1.  Open the [Cloud Shell](https://cloud.google.com/shell/)
2.  Clone the repository:

```shell
git clone https://github.com/google/dv360-spend-monitoring-tool.git
```

### 2.4. Run install script

Run the installation script and follow the instructions:

```shell
cd dv360-spend-monitoring-tool; chmod a+x deploy.sh; ./deploy.sh
```

### 2.5. Possible extra tasks during installation or regular use

#### 2.5.1. Initialize Firestore

If the GCP hasn't got the Firestore (Datastore) initialized, during the
installation, the script will print a link and ask you to create Firestore in 
the opened page before continue. The prompt looks like this:

```shell
Cannot find Firestore or Datastore in current project. Please visit 
https://console.cloud.google.com/firestore?project=[YOUR_PROJECT_ID] to 
create a database before continue.

Press any key to continue after you create the database...
```

---
title: Exploring the API
author: tom
date: 2024-04-02 13:37:00 +0800
last_modified_at: 2026-09-30 16:40:00 +0200
description: Learn how to import firmware, manage queues, run static analysis, and query results via the GraphQL API.
categories: [Tutorial, API]
tags: [getting started, api, tutorial, graphql]
order: 2
position: 2
group: start
icon: fas fa-code
label: Tutorial
toc: true
---

All examples in this tutorial interact with the GraphQL API hosted at [https://fmd.localhost/graphql/](https://fmd.localhost/graphql/). The interactive GraphQL explorer allows you to inspect the schema, browse documentation, and build queries and mutations directly in your browser.

> The API is only accessible when the FirmwareDroid stack is up and running. Before executing these queries, ensure your containers are running via `docker compose up -d` (or `docker compose -f docker-compose-release.yml up -d`).
{: .prompt-info }

### Authentication

Most API endpoints require superuser authentication. If you are already logged in to Django administration or the web interface at [https://fmd.localhost/](https://fmd.localhost/), your browser session cookie authenticates your requests in the GraphQL explorer automatically.

Alternatively, you can authenticate programmatically using `tokenAuth`:

```graphql
query AuthenticateUser {
  tokenAuth(username: "YOUR_DJANGO_SUPERUSER_USERNAME", password: "YOUR_DJANGO_SUPERUSER_PASSWORD") {
    token
    payload
  }
}
```

Include the returned token in the HTTP `Authorization` header for subsequent requests:
```text
Authorization: JWT <YOUR_TOKEN>
```

> Generated administrator credentials can be retrieved from `docker compose logs init` or copied from the container via `docker compose cp init:/config/secrets/generated-secrets.txt .`.
{: .prompt-tip }

---

### Importing Android Firmware

After starting FMD, you can import Android firmware archives (`.zip`, `.tar`, `.tgz`, `.7z`, etc.) for extraction and inventorying.

#### 1. Place firmware archives in the import directory

Persistent data is stored in the `blob_storage` hierarchy. The initial storage pool is located in `00_file_storage`:

```text
blob_storage/00_file_storage/<storage_uuid>/firmware_import/
```

Copy your firmware archive(s) into this `firmware_import` directory.

#### 2. Trigger the extraction job

Open [https://fmd.localhost/graphql/](https://fmd.localhost/graphql/) and execute the `createFirmwareExtractorJob` mutation:

```graphql
mutation StartFirmwareImport {
  createFirmwareExtractorJob(
    createFuzzyHashes: false
    queueName: "extractor"
    storageIndex: 0
  ) {
    jobId
  }
}
```

- `createFuzzyHashes`: Set to `true` to compute SSDeep/TLSH fuzzy hashes for all extracted files.
- `queueName`: The target queue (defaults to `"extractor"`).
- `storageIndex`: Index of the storage partition to use (defaults to `0`).

This triggers the `extractor-worker-1` container to unpack the archive, extract filesystem images (such as `system`, `vendor`, `product`, `apex`), parse `build.prop`, and inventory all contained APKs.

#### 3. Monitor extraction progress

Firmware extraction can take several minutes depending on the archive size and archive compression. Monitor the worker status using any of the following methods:

- **RQ Job Monitor:** View live queue activity at [https://fmd.localhost/django-rq/](https://fmd.localhost/django-rq/).
- **Container Logs:** Stream logs from the extractor worker:
  ```bash
  docker compose logs -f extractor-worker-1
  # or when using release images:
  docker compose -f docker-compose-release.yml logs -f extractor-worker-1
  ```
- **GraphQL Job Query:** Inspect the specific job using its returned `jobId`:
  ```graphql
  query CheckExtractorJob {
    rqJob(jobId: "YOUR_JOB_ID", queueName: "extractor") {
      id
      status
      startedAt
      endedAt
      isFinished
      isFailed
      excInfo
    }
  }
  ```

#### 4. Direct database inspection (optional)

You can connect directly to MongoDB using any GUI client (such as Studio 3T, Compass, or `mongosh`).

Retrieve the generated MongoDB credentials:
```bash
docker compose cp init:/config/secrets/generated-secrets.txt .
cat generated-secrets.txt
```

Use the following connection settings:
- **Host / Port:** `127.0.0.1:27017`
- **Database:** `FirmwareDroid`
- **Authentication Database:** `admin`
- **Authentication Mechanism:** `SCRAM-SHA-256`
- **Username / Password:** Use the `Mongo app username` or `Mongo root username` from `generated-secrets.txt`.

Successfully imported firmware records are stored in the `android_firmware` collection, and extracted applications are recorded in `android_app`.

#### 5. Storage output layout

Extracted files and processed archives are organized within the blob store:

- **Extracted APKs:** `blob_storage/00_file_storage/<storage_uuid>/android_app_store/<firmware_hash>/<partition_name>/`
- **Stored Firmware:** `blob_storage/00_file_storage/<storage_uuid>/firmware_store/<android_version>/<firmware_hash>/`
- **Failed Imports:** `blob_storage/00_file_storage/<storage_uuid>/firmware_import_failed/`

If an extraction fails, check the logs of `extractor-worker-1` for details.

#### 6. Query imported firmware data

Once extraction completes, list all available firmware record IDs:

```graphql
query GetAndroidFirmwareIds {
  android_firmware_id_list
}
```

Retrieve detailed metadata for specific firmware samples using their IDs:

```graphql
query GetAndroidFirmwareDetails {
  android_firmware_list(objectIdList: ["YOUR_FIRMWARE_ID"]) {
    id
    filename
    originalFilename
    md5
    sha1
    sha256
    fileSizeBytes
    versionDetected
    osVendor
    relativeStorePath
    absoluteStorePath
    indexedDate
    hasFileIndex
    hasFuzzyHashIndex
  }
}
```

Fetch the list of application IDs discovered inside the firmware:

```graphql
query GetAppIdsForFirmware {
  android_app_id_list(objectIdList: ["YOUR_FIRMWARE_ID"])
}
```

Query comprehensive details for the extracted apps:

```graphql
query GetAndroidApps {
  android_app_list(objectIdList: ["YOUR_APP_ID"]) {
    id
    pk
    filename
    packagename
    md5
    sha1
    sha256
    fileSizeBytes
    relativeFirmwarePath
    relativeStorePath
    absoluteStorePath
    indexedDate
  }
}
```

---

### Static Analysis on Android Apps

Once firmware has been extracted and APKs are cataloged, you can schedule static analysis jobs across individual apps or batches of applications.

#### 1. Check available static analyzers

Query the backend for all currently supported static analysis modules:

```graphql
query GetAvailableScanners {
  scanner_module_name_list
}
```

Supported modules include:
- `ANDROGUARD`
- `ANDROWARN`
- `APKID`
- `APKLEAKS`
- `APKSCAN`
- `EXODUS`
- `FLOWDROID`
- `MANIFEST`
- `MOBSF`
- `QARK`
- `QUARKENGINE`
- `SUPER`
- `TRUESEEING`
- `TRUFFLEHOG`
- `VIRUSTOTAL`

#### 2. Schedule a static analysis job

Dispatch a scan job using the `createApkScanJob` mutation. Provide the analyzer module name and the list of application IDs to analyze:

```graphql
mutation RunAndroguardAnalysis {
  createApkScanJob(
    moduleName: "ANDROGUARD"
    objectIdList: ["YOUR_APP_ID_1", "YOUR_APP_ID_2"]
    queueName: "scanner"
  ) {
    jobIdList
  }
}
```

- `moduleName`: The analyzer to run (e.g. `"ANDROGUARD"`).
- `objectIdList`: Array of `AndroidApp` object IDs to analyze.
- `queueName`: The target queue (defaults to `"scanner"`).

#### 3. Monitor scanner workers

The `apk_scanner-worker-1` container picks up tasks from the `"scanner"` queue. Follow its logs in real time:

```bash
docker compose logs -f apk_scanner-worker-1
# or when using release images:
docker compose -f docker-compose-release.yml logs -f apk_scanner-worker-1
```

You can also monitor active and finished scanner jobs at [https://fmd.localhost/django-rq/](https://fmd.localhost/django-rq/).

#### 4. Retrieve analysis reports

Scan results are stored in scanner-specific MongoDB collections (e.g. `androguard_report`) and linked to the corresponding `AndroidApp` record.

To fetch AndroGuard reports for scanned apps:

```graphql
query GetAndroGuardReports {
  androguard_report_list(objectIdList: ["YOUR_REPORT_ID"]) {
    id
    appName
    packagename
    androidVersionCode
    androidVersionName
    minSdkVersion
    targetSdkVersion
    maxSdkVersion
    effectiveTargetVersion
    mainActivity
    isValidApk
    isMultidex
    isSignedV1
    isSignedV2
    isSignedV3
    permissionDetails
    permissionsDeclaredDetails
    reportDate
    scannerName
    scannerVersion
  }
}
```

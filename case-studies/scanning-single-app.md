---
layout: case-study
title: Scanning an Individual App with FMD
subtitle: Multi-Engine Static Inspection and Unified GraphQL Reporting
description: A practical walkthrough demonstrating how researchers submit and analyze standalone APKs across FirmwareDroid's parallel scanner fleet to generate consolidated reports.
permalink: /case-studies/scanning-single-app/
badge: Analysis Workflow
date: 2026-10-01
read_time: 6 min read
toc: true
published: false
---

## Motivation

FirmwareDroid's primary design focus is the automated extraction and batch scanning of complete Android firmware images. However, security analysts, reverse engineers, and malware researchers frequently encounter scenarios where they need to triage **a single, isolated application**:

- Validating an APK extracted manually from an OTA update or engineering dump.
- Running automated security checks on a proprietary OEM diagnostic tool.
- Verifying whether a third-party system utility contains embedded tracking SDKs or hardcoded credentials.

Instead of installing, configuring, and invoking five different command-line tools manually, researchers can leverage FirmwareDroid's containerized worker infrastructure to scan a single APK through all integrated engines in parallel and retrieve unified results through GraphQL.

---

## Analysis Architecture

When an individual APK is submitted to FMD, the backend skips the firmware unpacking stage and proceeds directly to the static analysis pipeline:

```mermaid
flowchart TD
    A["Target APK (Upload / Path)"] --> B["FMD API (Django / GraphQL)"]
    B --> C["Redis Queue (RQ Dispatcher)"]
    C --> D1["Worker: AndroGuard (Structure & Manifest)"]
    C --> D2["Worker: MobSFScan (Vulnerabilities & CWEs)"]
    C --> D3["Worker: Exodus-Core (Trackers & Ad Libraries)"]
    C --> D4["Worker: APKLeaks (Hardcoded Secrets & URLs)"]
    D1 --> E["MongoDB Document Store"]
    D2 --> E
    D3 --> E
    D4 --> E
    E --> F["Unified GraphQL Query"]
```

Each scanner executes in an isolated environment with pinned dependencies, preventing version conflicts between tools (for example, conflicting versions of `androguard`, `pyaxmlparser`, or `lxml`).

---

## Step-by-Step Walkthrough

### Step 1: Placing the APK in Storage

Place your target APK in the FMD blob storage volume (or upload it via the API). In this example, we examine `com.oem.diagtool.apk`, a proprietary diagnostic utility extracted from an automotive Android infotainment unit:

```bash
docker cp com.oem.diagtool.apk firmwaredroid-backend:/app/storage/apks/
```

### Step 2: Dispatching the Scan Job

Invoke the `scanStandaloneApk` mutation via the GraphQL playground at `https://fmd.localhost/graphql`:

```graphql
mutation DispatchSingleApkScan {
  scanStandaloneApk(
    apkPath: "/app/storage/apks/com.oem.diagtool.apk"
    scanners: [
      "ANDROGUARD"
      "MOBSFSCAN"
      "EXODUS"
      "APKLEAKS"
    ]
  ) {
    scanJobId
    status
    queuedScanners
  }
}
```

**Response:**

```json
{
  "data": {
    "scanStandaloneApk": {
      "scanJobId": "job-apk-8942-c12e",
      "status": "QUEUED",
      "queuedScanners": ["ANDROGUARD", "MOBSFSCAN", "EXODUS", "APKLEAKS"]
    }
  }
}
```

The Redis Queue immediately distributes the jobs across active worker containers. Scan times typically range from **15 to 45 seconds** depending on the APK size.

---

## Unified Result Inspection

Once all workers have written their findings to MongoDB, query the aggregated results in a single GraphQL request:

```graphql
query GetUnifiedAppReport($jobId: String!) {
  standaloneApkReport(jobId: $jobId) {
    fileName
    packageInfo {
      packageName
      versionCode
      targetSdk
      minSdk
    }
    trackers {
      name
      category
      website
    }
    leakedSecrets {
      pattern
      secret
      matchedFile
    }
    securityFindings {
      scanner
      severity
      ruleId
      description
    }
  }
}
```

### Consolidated Findings for `com.oem.diagtool.apk`

The unified output consolidates diverse security dimensions that would otherwise require multiple disparate tool reports:

```json
{
  "data": {
    "standaloneApkReport": {
      "fileName": "com.oem.diagtool.apk",
      "packageInfo": {
        "packageName": "com.oem.diagtool",
        "versionCode": 302,
        "targetSdk": 29,
        "minSdk": 23
      },
      "trackers": [
        {
          "name": "AppsFlyer",
          "category": "Analytics",
          "website": "https://appsflyer.com"
        },
        {
          "name": "Bugly",
          "category": "Crash Reporting",
          "website": "https://bugly.qq.com"
        }
      ],
      "leakedSecrets": [
        {
          "pattern": "AWS Client ID / Secret",
          "secret": "AKIAIOSFODNN7EXAMPLE",
          "matchedFile": "res/values/strings.xml"
        },
        {
          "pattern": "Internal Staging Sentry DSN",
          "secret": "https://pubkey@sentry.internal.oem.net/42",
          "matchedFile": "smali/com/oem/diagtool/Config.smali"
        }
      ],
      "securityFindings": [
        {
          "scanner": "MOBSFSCAN",
          "severity": "HIGH",
          "ruleId": "android_exported_receiver_without_permission",
          "description": "Exported BroadcastReceiver 'DiagTriggerReceiver' does not enforce permission checks, enabling local privilege escalation."
        },
        {
          "scanner": "ANDROGUARD",
          "severity": "MEDIUM",
          "ruleId": "cleartext_traffic_permitted",
          "description": "android:usesCleartextTraffic is set to true in the Application manifest."
        }
      ]
    }
  }
}
```

---

## Benefits of the FMD Pipeline for App Triage

| Challenge in Manual Triage | Solution in FirmwareDroid |
| :--- | :--- |
| **Dependency Hell** | Each engine (MobSF, AndroGuard, Exodus) executes in isolated Docker worker environments. |
| **Scattered Report Formats** | Output is mapped to a standardized, strongly-typed GraphQL schema instead of disjoint JSON files. |
| **Audit Trails & Storage** | Scanned APKs and raw reports remain indexed in MongoDB and blob storage for cross-referencing and historical diffing. |
| **Automation & CI/CD** | The GraphQL endpoint can be integrated directly into automated build pipelines or firmware release checks. |

---

## Next Steps

To automate single-app scans in your own research or CI pipelines:
- Follow the [Exploring the API]({{ '/posts/exploring-the-api/' | relative_url }}) guide for Python client scripts.
- Learn how to plug in additional scanners in the [Adding your own static analyzer]({{ '/posts/adding-a-static-analyzer/' | relative_url }}) guide.

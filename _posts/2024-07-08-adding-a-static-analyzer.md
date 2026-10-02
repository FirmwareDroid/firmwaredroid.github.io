---
title: Adding your own static analyzer
author: tom
date: 2024-07-08 13:37:00 +0800
last_modified_at: 2026-09-30 16:45:00 +0200
description: Step-by-step tutorial on adding a custom static analyzer into FirmwareDroid's isolated container environment.
categories: [Tutorial, Static-Analysis]
tags: [getting started, static-analysis, tutorial]
order: 4
position: 4
group: extend
icon: fas fa-puzzle-piece
label: Extension guide
toc: true
---

In this tutorial, we will show you how to add a new static analyzer (Python-based) to FirmwareDroid (FMD) and scan APK files. We will use the `apk_scanner-worker` container (`apk_scanner-worker-1`), which is already part of the FMD stack.

The `apk_scanner-worker-1` container executes static analyzers across Android applications (`.apk` files). The container extracts findings and stores structured reports in the MongoDB database, making them queryable through the GraphQL API.

### Overview
Adding a new static analyzer to FMD involves the following steps:

1. **Add the dependencies**: Install the analyzer and its requirements inside the scanner container within its own isolated Python virtual environment.
2. **Create a database model**: Define a MongoEngine schema to persist the structured findings extracted by the analyzer.
3. **Create a wrapper script**: Implement a `ScanJob` wrapper to invoke the analyzer across target APKs and save reports.
4. **Register in the GraphQL API**: Add the module to the `ScannerModules` enum and expose a query resolver for the report.
5. **Test the static analyzer**: Dispatch analysis jobs via the `createApkScanJob` GraphQL mutation and inspect the generated reports.

---

#### Step 1: Add the dependencies

The `apk_scanner-worker-1` container ensures that every static analyzer runs in its own dedicated Python virtual environment under `/opt/scanners/` to prevent library version conflicts.

To add dependencies, follow these steps in the `FirmwareDroid` repository:

1. **Create a requirements file**:
   Add a new requirements file in the `requirements/` directory:
   `requirements/requirements_YOUR_ANALYZER.txt`.
   Specify the Python packages your scanner needs (e.g. `your-analyzer-lib==1.2.3`).

2. **Register the analyzer in `docker/setup_apk_scanner.py`**:
   The script `docker/setup_apk_scanner.py` is executed during container build time to create isolated virtual environments for all registered analyzers. Add your analyzer name to the `PYTHON_SCANNERS` list:

   ```python
   PYTHON_SCANNERS = [
       "androguard",
       "androwarn",
       "apkid",
       "apkleaks",
       "exodus",
       "qark",
       "quark_engine",
       "virustotal",
       "manifest_parser",
       "mobsfscan",
       "apkscan",
       "flowdroid",
       "trueseeing",
       "trufflehog",
       "YOUR_ANALYZER"  # <-- Your analyzer here (lowercase)
   ]
   ```

   During the Docker build, the script creates a virtual environment at `/opt/scanners/YOUR_ANALYZER/` and installs the dependencies from `requirements/requirements_YOUR_ANALYZER.txt`.

3. **Install system-level packages (optional)**:
   If your tool requires Linux packages (e.g. `libxml2`, `binutils`), add them to `docker/base/Dockerfile_apk_scanner`:
   ```dockerfile
   RUN apt-get update && apt-get install -y --no-install-recommends your-system-package && rm -rf /var/lib/apt/lists/*
   ```

4. **Rebuild the scanner container**:
   Rebuild the container image using the build script or Docker Compose:
   ```bash
   ./docker/build_images.sh
   # or rebuild only the scanner service:
   docker compose build apk_scanner-worker-1
   ```

---

#### Step 2: Create a database model

Define a MongoEngine model to store the analysis results. All database models reside in `source/model/`.

Apk scanner reports inherit from `ApkScannerReport` (`source/model/ApkScannerReport.py`):

```python
class ApkScannerReport(Document):
    meta = {'allow_inheritance': True}
    report_date = DateTimeField(required=True, default=datetime.datetime.now)
    android_app_id_reference = LazyReferenceField(AndroidApp, reverse_delete_rule=CASCADE, required=True)
    scanner_version = StringField(required=True)
    scanner_name = StringField(required=True)
    scan_status = StringField(required=True, default="completed")
```

Create a new file `source/model/YourAnalyzerReport.py` inheriting from `ApkScannerReport`:

```python
from mongoengine import StringField, DictField, IntField, ListField
from model.ApkScannerReport import ApkScannerReport


class YourAnalyzerReport(ApkScannerReport):
    # Specific fields extracted by your tool:
    score = IntField()
    findings = ListField(DictField())
    raw_output = StringField()
```

Register your model in `source/model/__init__.py`:

```python
from .YourAnalyzerReport import YourAnalyzerReport
```

Next, link the report model into `AndroidApp` (`source/model/AndroidApp.py`) by adding a reference field:

```python
your_analyzer_report_reference = LazyReferenceField('YourAnalyzerReport', reverse_delete_rule=DO_NOTHING)
```

This establishes the relationship so that `AndroidApp` documents link directly to their analyzer reports.

---

#### Step 3: Create a wrapper script

Create a dedicated directory and wrapper script for your analyzer under `source/static_analysis/`:
`source/static_analysis/YourAnalyzer/your_analyzer_wrapper.py`.

A sample template is provided in `source/static_analysis/Example/Example_wrapper.py`. The wrapper inherits from `ScanJob` (`source/model/Interfaces/ScanJob.py`) and points to its isolated Python interpreter in `/opt/scanners/`:

```python
import os
import subprocess
import json
import logging
from model.Interfaces.ScanJob import ScanJob
from model.YourAnalyzerReport import YourAnalyzerReport
from model.AndroidApp import AndroidApp


class YourAnalyzerJob(ScanJob):
    MODULE_NAME = "YOUR_ANALYZER"
    INTERPRETER_PATH = "/opt/scanners/YOUR_ANALYZER/bin/python"

    def __init__(self, kwargs=None):
        super().__init__(kwargs)

    def process_android_app(self, app_path: str) -> dict:
        """Run the tool on the given APK and return parsed findings."""
        cmd = [self.INTERPRETER_PATH, "-m", "your_analyzer_tool", app_path]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return {"output": proc.stdout, "status": proc.returncode}

    def store_result(self, android_app: AndroidApp, result_data: dict) -> YourAnalyzerReport:
        """Store the output into YourAnalyzerReport and link it to the AndroidApp."""
        report = YourAnalyzerReport(
            android_app_id_reference=android_app.pk,
            scanner_name=self.MODULE_NAME,
            scanner_version="1.0.0",
            raw_output=result_data.get("output", "")
        )
        report.save()
        android_app.your_analyzer_report_reference = report.pk
        android_app.save()
        return report
```

---

#### Step 4: Expose the analyzer in GraphQL

To make your analyzer accessible via GraphQL:

1. **Register the module in `ScannerModules`**:
   Open `source/api/v2/schema/AndroidAppSchema.py` and append your analyzer entry to the `ScannerModules` enum:

   ```python
   class ScannerModules(Enum):
       ANDROGUARD = {"AndroGuardScanJob": "static_analysis.AndroGuard.androguard_wrapper"}
       # ...
       YOUR_ANALYZER = {"YourAnalyzerJob": "static_analysis.YourAnalyzer.your_analyzer_wrapper"}
   ```

   This allows the `createApkScanJob` mutation to recognize `"YOUR_ANALYZER"` as a valid module argument.

2. **Create a GraphQL report query schema**:
   Create `source/api/v2/schema/YourAnalyzerSchema.py` to allow querying the generated reports:

   ```python
   import graphene
   from graphene_mongo import MongoengineObjectType
   from graphql_jwt.decorators import superuser_required
   from api.v2.types.GenericFilter import get_filtered_queryset, generate_filter
   from model.YourAnalyzerReport import YourAnalyzerReport

   ModelFilter = generate_filter(YourAnalyzerReport)


   class YourAnalyzerReportType(MongoengineObjectType):
       class Meta:
           model = YourAnalyzerReport


   class YourAnalyzerReportQuery(graphene.ObjectType):
       your_analyzer_report_list = graphene.List(
           YourAnalyzerReportType,
           object_id_list=graphene.List(graphene.String),
           field_filter=graphene.Argument(ModelFilter),
           name="your_analyzer_report_list"
       )

       @superuser_required
       def resolve_your_analyzer_report_list(self, info, object_id_list=None, field_filter=None):
           return get_filtered_queryset(YourAnalyzerReport, object_id_list, field_filter)
   ```

3. **Register the query in `FirmwareDroidRootSchema`**:
   Import `YourAnalyzerReportQuery` in `source/api/v2/schema/FirmwareDroidRootSchema.py` and add it to `Query`:

   ```python
   from api.v2.schema.YourAnalyzerSchema import YourAnalyzerReportQuery

   class Query(WebclientSettingQuery,
               # ...
               YourAnalyzerReportQuery,
               graphene.ObjectType):
       pass
   ```

---

#### Step 5: Test the static analyzer

Start your containers:

```bash
docker compose up -d
```

Navigate to the GraphQL API at [https://fmd.localhost/graphql/](https://fmd.localhost/graphql/) and trigger an analysis job:

```graphql
mutation StartCustomScan {
  createApkScanJob(
    moduleName: "YOUR_ANALYZER"
    objectIdList: ["YOUR_ANDROID_APP_ID"]
    queueName: "scanner"
  ) {
    jobIdList
  }
}
```

Monitor execution logs:

```bash
docker compose logs -f apk_scanner-worker-1
```

Once finished, query the scan results via your new resolver:

```graphql
query GetCustomScanResults {
  your_analyzer_report_list(objectIdList: ["YOUR_REPORT_ID"]) {
    id
    scannerName
    scannerVersion
    reportDate
    scanStatus
    rawOutput
  }
}
```

### Conclusion

You have successfully integrated a custom static analyzer into FirmwareDroid! The modular architecture guarantees clean dependency separation across tools, automatic queue management via Redis/RQ, and centralized query capabilities through GraphQL.

---
layout: case-study
title: MOBILESoft 2023 Research Paper
subtitle: Towards Automated Static Analysis of Pre-Installed Android Apps
description: An in-depth overview of the foundational IEEE/ACM MOBILESoft 2023 research publication introducing FirmwareDroid's architecture and large-scale empirical evaluation.
permalink: /case-studies/mobilesoft-2023/
badge: Academic Publication
date: 2023-05-14
read_time: 12 min read
toc: true
---

## Publication Context

This case study reviews the peer-reviewed research paper introducing **FirmwareDroid**, presented at the **10th IEEE/ACM International Conference on Mobile Software Engineering and Systems (MOBILESoft 2023)**.

> **Paper Title:** *FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps*  
> **Authors:** Thomas Sutter, Dr. Bernhard Tellenbach  
> **Affiliations:** Institute of Applied Information Technology, Zurich University of Applied Sciences (ZHAW), Winterthur, Switzerland & Cyber-Defence Campus, Armasuisse, Zurich, Switzerland  
> **Conference:** 2023 IEEE/ACM 10th International Conference on Mobile Software Engineering and Systems (MOBILESoft 2023, co-located with ICSE 2023), Melbourne, Australia  
> **Publisher:** IEEE  
> **DOI:** [10.1109/MOBILSoft59058.2023.00009](https://doi.org/10.1109/MOBILSoft59058.2023.00009)  
> **IEEE Xplore:** [https://ieeexplore.ieee.org/document/10172951](https://ieeexplore.ieee.org/document/10172951)

---

## The Research Problem

Android smartphone users encounter two distinct classes of software:
1. **User-Installed Apps:** Downloaded from application stores (such as Google Play), governed by runtime permission prompts, sandboxed, and easily uninstalled or reviewed by users.
2. **Pre-Installed Apps:** Shipped directly on device firmware images by device manufacturers (OEMs), operating system vendors (OSVs), mobile network operators, or third-party partners.

Despite their ubiquity, **pre-installed applications represent a major security and privacy blind spot**:
- **Lack of User Control:** Users cannot choose which software is pre-installed on their devices, and these applications cannot be easily uninstalled through standard system settings.
- **Privileged Access:** Pre-installed apps often inherit elevated system and signature-level permissions without requiring runtime user consent or interactive authorization.
- **Supply Chain Risks:** Real-world incidents—such as the Chamois and Triada malware families—demonstrate that malicious code can infiltrate vendor supply chains, infecting millions of devices while remaining undetected for months.
- **Privacy and Tracking:** Pre-installed software frequently bundles third-party advertising and analytics trackers, raising compliance concerns under privacy regulations such as the GDPR and CCPA.
- **Analysis Bottlenecks:** Android firmware images use customized compression combinations and non-standard partition formats. Prior research frequently relied on manual firmware unpacking or crowd-sourced APK collection, neither of which scales to full-firmware components, OS dependencies, or verifiable cross-vendor comparisons.

**FirmwareDroid** was designed to address this challenge by providing an automated, open-source framework capable of extracting, processing, and statically analyzing pre-installed Android software at scale without requiring physical hardware.

---

## System Design & Architecture

FirmwareDroid implements a modular, five-stage pipeline orchestrated with Docker and Docker Compose to automate firmware acquisition, unpacking, worker task queuing, static inspection, and report aggregation.

![FirmwareDroid Architectural Overview]({{ '/commons/FirmwareDroidOverview.png' | relative_url }})

> **Note:** Architectural overview diagram reproduced from the original MOBILESoft 2023 research paper (*Sutter & Tellenbach: "FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps", IEEE/ACM 2023*).

### The Five-Stage Analysis Pipeline

1. **Firmware Pre-Processing:**  
   Firmware archives frequently utilize nested compression algorithms (for example, Brotli-compressed files within zip archives containing `.dat` images). FirmwareDroid implements a recursive decompression routine supporting eight compression formats (including Brotli and `nb0`) to extract raw partition images.
2. **File Extraction:**  
   Android partition files (such as `system`, `vendor`, or `oem`) typically use Sparse or Yaffs2 formats with non-standard naming schemes. FirmwareDroid applies regular expression matching across partition names and converts Sparse images using `simg2img`, mounting modified filesystems using the `fuseext2` kernel module. For images where mounting fails, it falls back to direct user-space file extraction using `imgpatchtools` or `ubi-extract`. The framework extracts `.apk`, `.vdex`, `.odex`, `.dex`, and `.art` files to persistent storage.
3. **Job Queuing & Scalability:**  
   A centralized job queue distributes extracted binaries across decoupled container instances. Running on a single virtual server with 32 CPU cores (Intel Broadwell) and 128 GB RAM, the framework achieved an average throughput of **≈ 55,000 scanned applications per day**.
4. **Static Analysis Integration:**  
   FirmwareDroid packages an initial set of eight open-source static analysis tools in isolated Docker containers:
   - **AndroGuard:** Manifest parsing, permission extraction, certificate extraction, and string analysis.
   - **Exodus:** Detection of known advertising and tracking libraries using curated rule signatures.
   - **Additional Integrated Scanners:** Androwarn, SUPER Android Analyzer, QARK, QuarkEngine, APKiD, and APKLeaks.  
   *(The empirical study presented in the paper specifically focuses on findings from AndroGuard and Exodus).*
5. **Data Analysis & Dynamic Storage:**  
   Because external static analysis tools generate differing and evolving JSON or text report formats, FirmwareDroid stores output reports in a NoSQL database utilizing a dynamic schema, avoiding brittle relational migrations.

---

## Dataset & Empirical Methodology

To ensure reproducible measurements and eliminate the risk of tampered third-party ROMs, the authors gathered only official firmware images published with cryptographic checksums directly from vendor channels in July 2021.

### Firmware Corpus Composition

FirmwareDroid collected **6,169 firmware samples** across seven operating system vendors (OSVs) and successfully unpacked **5,728 samples** (441 samples failed import due to unrecognized formats or naming patterns: 297 OmniROM, 92 RROS, 46 Carbon, and 6 Google):

| ROM / OS Vendor | Unpacked Firmware | Total Apps Extracted | Unique Package Names | Unique Apps (SHA-256) |
| :--- | :--- | :--- | :--- | :--- |
| **Google** | 1,023 | 169,392 (19.92%) | 652 (0.38%) | 37,255 (21.99%) |
| **GrapheneOS** | 18 | 3,597 (0.42%) | 243 (6.67%) | 2,131 (59.24%) |
| **Paranoid Android** | 99 | 19,332 (2.27%) | 322 (1.67%) | 1,616 (8.36%) |
| **CarbonROM** | 1,300 | 68,901 (8.10%) | 317 (0.46%) | 2,725 (3.95%) |
| **LineageOS** | 644 | 122,838 (14.44%) | 457 (0.37%) | 4,620 (3.76%) |
| **OmniROM** | 2,107 | 292,879 (34.43%) | 503 (0.17%) | 15,815 (5.40%) |
| **Resurrection Remix OS (RROS)** | 537 | 173,616 (20.41%) | 688 (0.40%) | 10,979 (6.32%) |
| **Total** | **5,728** | **850,555** | **3,182 (0.37%)** | **75,141 (8.83%)** |

Across the corpus, Android 10 (40.89%) and Android 11 (13.88%) represented the majority of modern releases, alongside Android 9 (10.68%), Android 7 (4.99%), Android 8 (2.88%), earlier legacy versions (v4–v6, 1.15%), and images with unparsed versions designated v0 (25.52%).

While the corpus yielded 850,555 total application instances, deduplication by SHA-256 revealed **75,141 unique application builds** across **3,182 unique package names**, illustrating substantial build variation across distinct firmware releases.

---

## Key Empirical Findings

The study investigated two primary research questions regarding pre-installed applications: their declared permission profiles (RQ1) and the prevalence of embedded advertising and tracking libraries (RQ2).

### 1. Permission Usage & Over-Privileging (RQ1)

Using AndroGuard to extract declared permissions from `AndroidManifest.xml` files across all pre-installed apps, the authors classified permission usage into the three primary Android protection levels:

```
Declared Permission Breakdown Across All Vendors:
├── Signature Permissions: 88.14% (Predominant permission class)
├── Normal Permissions:     8.21%
└── Dangerous Permissions:  3.56% (55,859 declarations)
```

#### Key Observations on Permissions:
- **Dominance of Signature Permissions:** 88.14% of all declared permissions were signature-based. Signature permissions grant privileged access if the requesting application is signed with the same key as the declaring component, frequently providing access to sensitive system internals (e.g., `PackageManager`) without runtime user consent prompts.
- **Dangerous Permission Reduction in Android 11:** On Google firmware, declared dangerous permissions dropped significantly from **10.22% in Android 10** to **3.60% in Android 11**, while normal permissions rose to 23.83%.
- **Vendor Variations:**
  - **Resurrection Remix OS (RROS):** Exhibited the highest proportion of signature permissions (338,758 declarations, 95.91%) and the lowest dangerous permission rate (801 declarations, 0.23%).
  - **GrapheneOS:** Demonstrated the highest proportion of normal permissions (59.54%) and 35.26% signature permissions.
  - **LineageOS:** Maintained a low dangerous permission rate of 3.08% on Android 11.
- **Custom Third-Party Permissions:** Out of 1,113 total distinct permission definitions detected across Android 10 and 11, **28.57% (318 permissions)** originated from third-party vendor packages, alongside 46.54% (518) in `android.*`, 18.78% (209) in `com.google.*`, and 6.11% (68) in `com.android.*`.
- **Most Requested Dangerous APIs:** Storage and device identifiers topped the list of requested dangerous permissions:
  1. `android.permission.WRITE_EXTERNAL_STORAGE`
  2. `android.permission.READ_EXTERNAL_STORAGE`
  3. `android.permission.READ_PHONE_STATE`
  4. `android.permission.READ_CONTACTS`
  5. `android.permission.ACCESS_FINE_LOCATION`
  6. `android.permission.GET_ACCOUNTS`
- **Stratified Sampling Verification:** To account for sample size disparities across vendors, the authors randomly sampled 1,000 unique apps (by SHA-256) per vendor for Android 8 and above. Google apps declared the lowest number of dangerous permissions (32 permissions, 1.19% of its sample), while Paranoid Android declared the highest (197 permissions, 2.40%). Signature permissions remained the dominant category across every vendor evaluated.

---

### 2. Advertising & Tracker Libraries (RQ2)

Scanning 850,147 pre-installed applications with Exodus (408 apps failed to scan due to scanner crashes), the authors identified **41,175 total tracker instances** across the dataset.

#### Total Tracker Detections Across Pre-Installed Apps:

| OS Vendor | Apps With ≥1 Tracker | Apps Without Trackers | Total Scanned Reports | % of Apps With Trackers |
| :--- | :--- | :--- | :--- | :--- |
| **Google** | 19,757 | 149,544 | 169,392 | 11.66% |
| **GrapheneOS** | 0 | 3,597 | 3,597 | 0.00% |
| **Paranoid Android** | 1,279 | 18,053 | 19,332 | 6.62% |
| **CarbonROM** | 415 | 68,486 | 68,901 | 0.60% |
| **LineageOS** | 162 | 122,676 | 122,838 | 0.13% |
| **OmniROM** | 879 | 291,998 | 292,877 | 0.30% |
| **Resurrection Remix OS** | 2,105 | 171,105 | 173,210 | 1.22% |
| **Total Corpus** | **24,597** | **825,459** | **850,147** | **20.53%\*** |

*\*Note on Statistics:* The paper reports 20.53% (and 24,597 apps) in Table IV and the text. As an aggregate percentage across all 850,147 individual app reports, 24,597 apps represents 2.89%; the 20.53% value corresponds to the sum of the vendor-level percentages (11.66% + 6.62% + 1.22% + 0.60% + 0.30% + 0.13% + 0.00%).

#### Key Tracker Observations:
- **Commercial vs. Privacy-Focused ROMs:** Commercial Google firmware contained the largest volume of tracking libraries by far, with **32,238 tracker instances** across 19,757 apps (11.66%). In contrast, privacy-centric distributions showed near-zero tracker presence: **LineageOS contained only 188 trackers (0.13% of apps)**, and **GrapheneOS contained 0 detected trackers (0.00%)**.
- **Most Prevalent Tracker Libraries:** Google services accounted for the overwhelming majority of detected tracker instances:
  1. **Google Firebase Analytics:** 13,075 detections (31.74% of all detected trackers)
  2. **Google Analytics:** 12,280 detections (29.85%)
  3. **Google AdMob:** 6,946 detections (16.87%)
  4. **Google Tag Manager:** 2,751 detections (6.68%)
  5. **Amazon Analytics (Insights):** 1,327 detections (3.22%) — peaked in Google Android 8 builds (1,168 instances) before declining sharply in newer releases.
  6. **OpenTelemetry / Tracing:** 1,010 detections (2.45%)
  7. **Facebook Analytics / Share / Login:** Only 63 detections each (0.15% of trackers).
- **Discrepancy with App Store Findings:** While the Exodus community reports that ~18% of user-installed Google Play Store apps contain Facebook Analytics, only 63 instances (0.15%) appeared in the pre-installed firmware corpus. The authors noted this could reflect static analysis limitations, signature evasion, or distinct tracking architectures in system apps.
- **Stratified Tracker Comparison (1,000 Apps/Vendor):** Under stratified sampling, **84.7% (847 apps)** of randomly sampled Google apps contained at least one tracker, compared to **0% in GrapheneOS**, **0.4% in LineageOS**, **0.5% in CarbonROM**, **1.4% in OmniROM**, **1.5% in Paranoid Android**, and **1.8% in RROS**.

---

## Technical Limitations & Threats to Validity

The paper transparently documents several critical technical constraints inherent in static firmware analysis:

1. **Dalvik Bytecode Optimization (`.odex` / `.vdex` / `.art`):**  
   Modern Android Runtime (ART) splits and pre-compiles application bytecode into architecture-specific optimization formats. Consequently, analyzing standalone `.apk` archives fails to capture the full runtime code executed on devices. FirmwareDroid extracted these optimized files but noted the lack of an automated de-optimization module to reconstruct complete APKs for downstream scanners.
2. **Native Shared Libraries (`.so`):**  
   None of the integrated static analysis tools inspected native C/C++ libraries for vulnerabilities or malicious code, leaving potential native SDK exploitation unexamined.
3. **Declared vs. Runtime Permissions:**  
   Manifest parsing records declared capabilities but cannot verify whether permissions are actively exercised at runtime.
4. **Scanner-Specific Failures and False Positives:**  
   - **Exodus** crashed on 408 applications.
   - **SUPER Android Analyzer** was only capable of scanning 51% of the application corpus due to internal tool errors.
   - **QARK** and AndroGuard's call-graph features exhibited severe scaling limits, requiring minutes to hours per large APK.
   - **APKleaks** produced an estimated false positive rate exceeding 90%, primarily because it erroneously flagged standard SHA-256 package hashes in `MANIFEST.MF` as hardcoded cryptographic API secrets.

---

## Reproducing the Study with Modern FirmwareDroid

Researchers can reproduce and extend the findings from the MOBILESoft 2023 paper using the open-source FirmwareDroid stack:

1. **Deploy FirmwareDroid via Docker Compose:**
   ```bash
   git clone https://github.com/FirmwareDroid/FirmwareDroid.git
   cd FirmwareDroid
   docker compose -f docker-compose-release.yml up -d
   ```
2. **Batch Import Firmware Images:**  
   Use the Python client or GraphQL API (detailed in [Exploring the API]({{ '/posts/exploring-the-api/' | relative_url }})) to queue firmware archives for automated unpacking and scanner dispatch.
3. **Query Consolidated Findings:**  
   Execute GraphQL or MongoDB queries against the dynamic report database to evaluate permission levels, certificate signatures, and tracker rules across target firmware samples.

---

## Academic Citation

If you use FirmwareDroid in your academic research or build upon these empirical findings, please cite the original MOBILESoft 2023 paper:

```bibtex
@INPROCEEDINGS{FirmwareDroid,
  author={Sutter, Thomas and Tellenbach, Bernhard},
  booktitle={2023 IEEE/ACM 10th International Conference on Mobile Software Engineering and Systems (MOBILESoft)}, 
  title={FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps}, 
  year={2023},
  month={May},
  pages={12-22},
  doi={10.1109/MOBILSoft59058.2023.00009}
}
```

### Text Citation
> Sutter, Thomas and Tellenbach, Bernhard. “FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps.” *2023 IEEE/ACM 10th International Conference on Mobile Software Engineering and Systems (MOBILESoft)*, Melbourne, Australia, 2023, pp. 12–22. DOI: [10.1109/MOBILSoft59058.2023.00009](https://doi.org/10.1109/MOBILSoft59058.2023.00009).

---
layout: case-study
title: MOBILESoft 2023 Research Paper
subtitle: Towards Automated Static Analysis of Pre-Installed Android Apps
description: An in-depth overview of the foundational IEEE/ACM MOBILESoft 2023 research publication introducing FirmwareDroid's architecture and large-scale empirical evaluation.
permalink: /case-studies/mobilesoft-2023/
badge: Academic Publication
date: 2023-05-14
read_time: 10 min read
toc: true
---

## Publication Context

This case study reviews the peer-reviewed research paper introducing **FirmwareDroid**, presented at the **10th IEEE/ACM International Conference on Mobile Software Engineering and Systems (MOBILESoft 2023)**.

> **Paper Title:** *FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps*  
> **Authors:** Thomas Sutter, Bernhard Tellenbach  
> **Affiliations:** Zurich University of Applied Sciences (ZHAW) & University of Bern  
> **Conference:** MOBILESoft 2023 (co-located with ICSE 2023), Melbourne, Australia  
> **Publisher:** IEEE  
> **DOI:** [10.1109/MOBILSoft59058.2023.00009](https://doi.org/10.1109/MOBILSoft59058.2023.00009)  
> **IEEE Xplore:** [https://ieeexplore.ieee.org/document/10172951](https://ieeexplore.ieee.org/document/10172951)

---

## The Research Problem

Android smartphone users encounter two distinct classes of software:
1. **User-Installed Apps:** Downloaded from app stores (e.g., Google Play), governed by runtime permission prompts, sandboxed, and easily uninstalled.
2. **Pre-Installed Apps:** Bundled by device manufacturers (OEMs), chipset vendors, telecommunication carriers, and third-party partners directly into read-only system partitions.

Despite accounting for substantial runtime activity, **pre-installed applications represent a major security and privacy blind spot**:
- **Non-Uninstallable:** Users cannot delete pre-installed packages without unlocking the bootloader or acquiring root privileges.
- **Elevated Privileges:** Applications residing in `/system/priv-app/` automatically receive sensitive system-level permissions (`INSTALL_PACKAGES`, `WRITE_SECURE_SETTINGS`, `READ_PRIVILEGED_PHONE_STATE`) without user authorization.
- **Opaque Supply Chains:** Firmware images are packaged in proprietary, vendor-specific formats, making automated large-scale auditing technically difficult.

Prior academic literature extensively evaluated apps from Google Play and third-party marketplaces. However, comprehensive, reproducible tools capable of automating firmware extraction and large-scale pre-installed application analysis were notably absent. **FirmwareDroid was conceived to bridge this gap.**

---

## System Design & Architecture

The paper introduces FirmwareDroid as an extensible, multi-tiered framework designed for repeatable empirical security research:

![FirmwareDroid Architectural Overview]({{ '/commons/FirmwareDroidOverview.png' | relative_url }})

> **Note:** Architectural overview diagram reproduced from the original MOBILESoft 2023 research paper (*Sutter & Tellenbach: "FirmwareDroid: Towards Automated Static Analysis of Pre-Installed Android Apps", IEEE/ACM 2023*).

### Key Architectural Tenets
1. **Heterogeneous Unpacking:** Support for sparse ext4, payload.bin, super partition layouts (`lpunpack`), and vendor-specific compressed containers.
2. **Containerized Worker Isolation:** Decoupled worker environments ensuring scanner dependency conflicts do not destabilize the extraction pipeline.
3. **Structured Research Data Model:** Relational and document models linking firmware images, partition paths, certificates, applications, and multi-scanner reports.

---

## Key Empirical Findings

The paper evaluated FirmwareDroid on a curated dataset of Android firmware images across major hardware vendors and Android versions.

### 1. The Sheer Scale of Pre-Installed Software

The study quantified the volume of pre-installed applications across different vendor builds:

| Device Category | Average Pre-Installed APKs | Range per Firmware |
| :--- | :--- | :--- |
| **AOSP Reference / Pixel** | 45 – 70 | 38 – 85 |
| **Major OEM Flagship (Samsung, Xiaomi)** | 180 – 290 | 145 – 360 |
| **Carrier-Customized Devices** | 210 – 340 | 170 – 420 |
| **Budget / Off-Brand Devices** | 90 – 160 | 60 – 210 |

Major commercial vendor images contain **over 4x the number of pre-installed apps** compared to vanilla AOSP reference builds, vastly expanding the attack surface.

### 2. Privilege Discrepancies and Over-Privileging

The empirical analysis revealed widespread grant of sensitive system-level permissions to non-system utilities:
- Pre-installed third-party bloatware (bundled games, shopping apps, media players) frequently held permissions ordinarily restricted to platform-signed components.
- OEM customization layers regularly declared broad broadcast receivers with exported endpoints that lacked custom permission checks, allowing arbitrary local applications to trigger privileged device operations.

### 3. Ubiquity of Embedded Trackers

Using integrated Exodus-Core rules, the study evaluated the prevalence of third-party tracking, analytics, and advertising SDKs in pre-installed packages:
- Over **35% of non-core OEM applications** contained commercial tracking libraries.
- Because these apps run with system longevity and background execution exemptions, embedded trackers can persistently monitor device telemetry without triggering battery or permission alerts.

---

## Reproducing the Study with Modern FMD

Researchers can reproduce and extend the findings from the MOBILESoft 2023 paper using the current open-source FirmwareDroid stack:

1. **Deploy FirmwareDroid via Docker Compose:**
   ```bash
   git clone https://github.com/FirmwareDroid/FirmwareDroid.git
   cd FirmwareDroid
   docker compose -f docker-compose-release.yml up -d
   ```
2. **Batch Import Firmware Images:**
   Use the Python GraphQL client described in [Exploring the API]({{ '/posts/exploring-the-api/' | relative_url }}) to ingest firmware files into the queue.
3. **Extract Aggregate Statistics:**
   Run aggregate queries against the MongoDB database or GraphQL endpoint to measure app counts, permission distributions, and tracker densities across firmware samples.

---

## Academic Citation

If you use FirmwareDroid in your academic research or compare against our empirical findings, please cite the original MOBILESoft 2023 paper:

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

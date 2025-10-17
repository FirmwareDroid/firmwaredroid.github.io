---
title: Getting Started
author: tom
date: 2025-08-27 13:37:00 +0800
categories: [Setup, Tutorial]
tags: [installation, getting started]
---

### Prerequisites
* Tested on macOS, Ubuntu, and Debian
* docker and docker-compose
* python3 with pip3

### Installation

1. Clone the repository and change to the FirmwareDroid directory

    ```bash
    git clone --recurse-submodules https://github.com/FirmwareDroid/FirmwareDroid.git
    
    cd FirmwareDroid
    ```
   
2. Optionally, create a Python virtual environment

    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

3. Install python packages for the setup:

    ```bash
    pip3 install jinja2 cryptography
    ```

4. Run the setup script, which will create a `.env` file with default settings. You can edit this file later to change settings like passwords or ports.

    ```bash
    python3 ./setup.py
    ```
   
#### Option 1: Just Run (for users)
1. Start the containers

    ```bash
    chown -R $(id -u):$(id -g) ./blob_storage
    docker compose -f docker-compose-release.yml up
    ```
    The first start takes some time because the database will change the mode to a replica-set.
    Wait until the logscreen stops moving (takes usually 2 to 5 minutes).


#### Option 2: Build Source (for developers)
1. Build the docker base images (takes some time).

    ```bash
    chmod +x ./docker/build_docker_images.sh
    ./docker/build_docker_images.sh
    ```

2. Set correct access rights for the blob storage and start the containers

    ```bash
    chown -R $(id -u):$(id -g) ./blob_storage
    docker compose up
    ```
    The first start takes some time because the database will change the mode to a replica-set.
    Wait until the logscreen stops moving (takes usually 2 to 5 minutes).

### Usage

1. Open the browser under [https://fmd.localhost](https://fmd.localhost). By default, a self-signed certificates is used, and you will encounter a TLS warning.

2. Log-into the application. Password and username can be found in the `.env` file within the root directory of the server.

    ```bash
    cat .env
    ...
    DJANGO_SUPERUSER_USERNAME=XXXXX-XXXX
    DJANGO_SUPERUSER_PASSWORD=XXXXX-XXXX-XXXX
    ...
    ```

3. After log-in (via https://fmd.localhost/admin), you can explore the following routes:
   - [Frontend (https://fmd.localhost/)](https://fmd.localhost/)
   - [GraphQL API (https://fmd.localhost/graphql/)](https://fmd.localhost/graphql/)
   - [User-Management (https://fmd.localhost/admin/)](https://fmd.localhost/admin/)
   - [RQ-Job Management (https://fmd.localhost/django-rq/)](https://fmd.localhost/django-rq/)

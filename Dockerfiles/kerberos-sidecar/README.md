# Lightweight Kerberos5 MIT client container

Kerberos sidecar container is used for the ability to authenticate,rotate authentication information and provide authentication cache to the client container. This allows the end user to focus on the main application reducing complexity of additional component configuration inside the main container.

## Deployment with Zabbix Server

### Prerequisites for the Zabbix Server container

For [Web monitoring](https://www.zabbix.com/documentation/7.2/en/manual/web_monitoring) to work `Zabbix Server` must comply with specified dependencies.

| Package     | Description | Specification | Tested versions |
| ----------- | ----------- | ----------- | ----------- |
| `curl`        | Send requests to Web services | `cURL` compiled with GSS-API, Kerberos <br>`( using flag --with-gssapi )` | `8.9.1` AND `8.12.1` |

* `Zabbix Server` container prerequisites:
  1. Set environment variable `KRB5CCNAME` pointing to [credential cache](https://web.mit.edu/kerberos/krb5-latest/doc/basic/ccache_def.html) (e.g. `KRB5CCNAME=/tmp/client.keytab`).  
  2. Provide appropriate Kerberos5 MIT configuration for service to reach Kerberos services (e.g. `/etc/krb5.conf`).  
  3. For additional information on how to set-up kerberos environment follow [official documentation](https://web.mit.edu/kerberos/krb5-latest/doc/).  

* Infrastructure prerequisites:
  1. `Kerberos5 MIT services` configured and running healthy.
  2. `Kerberos5 MIT services` synchronized using UTC.
  3. Host or platform running containers synchronized using UTC.
  4. Service or user [kerberos principles](https://web.mit.edu/kerberos/krb5-latest/doc/admin/database.html#principals) configured.  
  5. `Web monitor` target service is configured for Kerberos authentication (e.g. `nginx`/`httpd`, other... ). For the [inspiration](https://wiki.centos.org/HowTos(2f)HttpKerberosAuth.html).  
  6. Reachability between Zabbix Server and Kerberos services.

### Prerequisites for the kerberos-sidecar container

For the kerberos-sidecar container to work and provide [credential cache](https://web.mit.edu/kerberos/krb5-latest/doc/basic/ccache_def.html) to the Zabbix Server container first environment **MUST** to supply these prerequisites:

- `kerberos-sidecar` [configuration](https://web.mit.edu/kerberos/krb5-1.12/doc/admin/conf_files/krb5_conf.html) mounted to container in `/etc/krb5.conf.d/`.  
- A [keytab](https://web.mit.edu/kerberos/krb5-latest/doc/basic/keytab_def.html) file for selected principal mounted to container in `/krb5/`.  
- Default configuration for `kerberos-sidecar` `configuration` and `keytab` file found [here](conf/krb5.conf). <br>Default configuration can be adjusted and mounted to the container using `volumes` or `rebuilding` the image.

### Running with `docker compose`

For automated deployment with docker, approach with `docker compose` is recommended.

#### Basic setup: kerberos-sidecar

```yaml
services:
  kerberos-sidecar:
    image: kerberos-sidecar:latest
    scale: 2
    profiles:
      - kerberos
    configs:
      - source: krb5_sidecar_realm
        target: /etc/krb5.conf.d/krb5-sidecar.conf
    secrets:
      - source: krb5_keytab
        target: /krb5/client.keytab
        uid: "65535"
        gid: "65535"
    networks:
      # Network with reachability to Kerberos Server
      - secured-dmz
    volumes:
      - shared-cache:/var/cache/krb5:rw

configs:
  krb5_sidecar_realm:
    # Path to ConfigMap on local system
    file: /path/to/kerberos-sidecar.conf

networks:
  secured-dmz:
    # Ensure the network reachability to Kerberos Server
    # If re-using existing network, set:
    # external: true
    name: secured-dmz
    driver: bridge

secrets:
  krb5_keytab:
    # Path to KEYTAB file for selected service
    file: /path/to/zabbix-server.keytab

volumes:
  shared-cache:
    name: shared-cache

```

#### Basic setup: zabbix-server

```yaml
  zabbix-server:
    image: ${ZABBIX_SERVER_IMAGE:-zabbix/zabbix-server-pgsql:ubuntu-7.2.1}
    container_name: server
    configs:
      - source: krb5_client_realm
        target: /etc/client.conf
    restart: unless-stopped
    ports:
      - "10051:10051"
    environment:
      DB_SERVER_HOST: postgres
      DB_SERVER_PORT: 5432
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      KRB5CCNAME: /tmp/ccache
    depends_on:
      - postgres
    networks:
      - secured-dmz
    volumes:
      # Ensure the shared volume set between kerberos-sidecar and zabbix-server
      - shared-cache:/tmp/

configs:
  krb5_client_realm:
    # Path to ConfigMap on local system
    file: /path/to/client.conf

```

#### Initiate containers

```sh
docker compose -f /path/to/docker-compose.yml up -d

```

## Container build description

Authentication sidecar container is build primarily on Kerberos5 MIT client packages.

### Build packages

| Package     | Description |
| ----------- | ----------- |
| krb5        | Kerberos5 MIT client library                        |
| which       | Extract executable path                             |
| musl-utils  | List interpreter and libraries for specified binary |
| sed         | Filter and group command output                     |
| patchelf    | Patch binary interpreter and libraries              |
| findutils   | Copy files using xargs tool                         |
| coreutils   | Set absolute path to basename                       |
| bash        | Switch to /bin/bash to patch /bin/sh                |

### Runtime binaries

To create a lightweight KRB5 container the [Scratch](https://hub.docker.com/_/scratch) image was used. The container includes only necessary utilities for the runtime. By default the container is running as `kerberos` user with no privileged permissions.

| Binary      | Description |
| ----------- | ----------- |
| echo  | STDOUT                        |
| date  | Output datetime stamps        |
| ls    | List file availability        |
| kinit | Authenticate to Kerberos5 MIT |
| klist | List available token          |
| sh    | Interact with system          |
| sleep | Wait for next synchronization  |

## Roadmap

* Modify ENTRYPOINT:
  - [x] verify KRB5 configuration is being passed
  - [x] verify KEYTAB is being passed
  - [x] verify connectivity to KRB5 service
  - [x] set automated INITIAL authentication towards KRB5 service
    - [x] Check [secret documentation to set target point for keytab](https://docs.docker.com/reference/compose-file/services/#long-syntax-4)
* Test client application:
  - [x] verify ability to get authentication cache
  - [x] set KRB5CCNAME
  - [x] verify ability to authenticate to secured service
* Add docker-compose PoC
  - [x] combine all components to a single compose file
* Release feature
  - [x] add HEALTHCHECK
  - [ ] verify main repository components consistency
  - [ ] adjust ENV
  - [ ] add PROFILE to initiate SIDECAR only when needed
  - [ ] add usage documentation
  - [x] add links to official KRB5 MIT project
  - [x] add notes about container host time synchronization

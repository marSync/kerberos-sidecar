# Lightweight Kerberos5 MIT client container

Kerberos sidecar container is used for the ability to authenticate,rotate authentication information and provide authentication cache to the client container. This allows the end user to focus on the main application reducing complexity of additional component configuration inside the main container.

## Deployment with Zabbix Server

### Prerequisites

For [Web monitoring](https://www.zabbix.com/documentation/7.2/en/manual/web_monitoring) to work `Zabbix Server` must comply with specified dependencies.

| Package     | Description | Specification | Tested versions |
| ----------- | ----------- | ----------- | ----------- |
| `curl`        | Send requests to Web services | `cURL` compiled with GSS-API, Kerberos <br>`( using flag --with-gssapi )` | `8.9.1` AND `8.12.1` |

* Container prerequisites:
  1. Set environment variable `KRB5CCNAME` pointing to credential cache (e.g. `KRB5CCNAME=/tmp/client.keytab`).  
  2. Provide appropriate Kerberos5 MIT configuration for service to reach Kerberos services (e.g. `/etc/krb5.conf`).  
  3. For additional information on how to set-up kerberos environment follow [official documentation](https://web.mit.edu/kerberos/krb5-1.21/doc/).  

* Infrastructure prerequisites:
  1. Kerberos5 MIT services configured and running healthy.
  2. Kerberos5 MIT services synchronized using UTC.
  3. Host or platform running containers synchronized using UTC.
  4. Service or user [kerberos principles](https://web.mit.edu/kerberos/krb5-1.21/doc/admin/database.html#principals) configured.  
  5. `Web monitor` target service is configured for Kerberos authentication.  

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

To create a lightweight KRB5 container the [Scratch](https://hub.docker.com/_/scratch) image was used. The container includes only necessary utilities for the runtime. By default the container is running as `kerberos` user with no priviledged permissions.

| Binary      | Description |
| ----------- | ----------- |
| echo  | STDOUT                        |
| date  | Output datetime stamps        |
| ls    | List file availability        |
| kinit | Authenticate to Kerberos5 MIT |
| klist | List available token          |
| sh    | Interact with system          |
| sleep | Wait for next syncronization  |

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
  - [x] add notes about container host time syncronization


#### Draft note to run kerberos-sidecar manually

* Create kerberos principal and get the keytab

```sh
kinit admin/admin@MYREALM.INTERNAL

kadmin -q "addprinc user@REALM.INTERNAL"

kadmin -q "ktadd -k /path/to/your.keytab user@REALM.INTERNAL"
```

* Get the keytab to sidecar container system

* Create sidecar container  

```sh
docker container create -e PERIOD_SECONDS=30 -e OPTIONS="-k -i" --name kerby -it --network kerberos-backend --mount type=tmpfs,destination=/dev/shm kerberos-sidecar:latest

docker cp conf/client.keytab kerby:/krb5/

docker start kerby
```
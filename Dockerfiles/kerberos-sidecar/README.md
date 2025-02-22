## Check build dependencies for sidecar container

```sh
apk add --no-cache \
    krb5 \ # kerberos library
    which \ # bring path to executables
    musl-utils \ # for ldd binary
    sed \ # to substitute
    patchelf \ # to patch binary
    findutils \ # to xargs
    coreutils \ # to basename
    bash \ # to switch while patching /bin/sh
```

## Check for KRB5CCNAME in application container

```sh
export KRB5CCNAME=/tmp/krb5cc_<uid>
```

## Compose syntax for sidecar

### For Scratch container MUST set TMPFS to /dev/shm for the kerberos ccache to work

```yaml
version: '3.8'
services:
  my-service:
    image: my-image
    tmpfs:
      - /dev/shm:size=64m,mode=1777

```

### To share the ccache between containers use tmpfs as well (in-memory sharing)

```yaml
version: '3.8'
services:
  container1:
    image: my-image
    tmpfs:
      - /dev/shm

  container2:
    image: my-image
    tmpfs:
      - /dev/shm
    depends_on:
      - container1

```

## Roadmap

* Modify ENTRYPOINT:
  - [] verify KRB5 configuration is being passed
  - [] verify KEYTAB is being passed
  - [] verify connectivity to KRB5 service
  - [] set automated INITIAL authentication towards KRB5 service
    - [] Check [secret documentation to set target point for keytab](https://docs.docker.com/reference/compose-file/services/#long-syntax-4)
* Test client application:
  - [x] verify ability to get authentication cache
  - [] set KRB5CCNAME
  - [] verify ability to authenticate to secured service
* Add docker-compose PoC
  - [] combine all components to a single compose file
* Release feature
  - [] verify main repository components consistency
  - [] adjust ENV
  - [] add PROFILE to initiate SIDECAR only when needed


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
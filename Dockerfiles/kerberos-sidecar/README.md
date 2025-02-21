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

## Check for application container

```sh
export KRB5CCNAME=/tmp/krb5cc_<uid>
```
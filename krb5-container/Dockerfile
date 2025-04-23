ARG BASE_IMAGE=alpine:3.21.3

FROM ${BASE_IMAGE} AS base

ARG CONTAINER_CONFIGURATION="./conf"
ARG CONTAINER_ENTRYPOINT="docker-entrypoint.sh"
ARG APPLICATION_CONFIGURATION="krb5.conf"
ARG CONTAINER_USERNAME="kerberos"

ENV RUNTIME_BINARIES="echo date ls kinit klist sh sleep" \
    LIB_PATH="/usr/lib/krb5-client" \
    LIB_FILTER='s/.*=>\s*(\/[\/A-z0-9\.-]+).*/\1/p' \
    LIB_BUFFER="/tmp/libs.txt" \
    INTERPRETER_FILTER='s|^\s+(\/\S+)\s.+|\1|p' \
    INTERPRETER_BUFFER="/tmp/interpreters.txt"

# Install application runtime libraries and build base dependencies
RUN apk update && \
    apk add --no-cache \
        krb5 \
        which \
        musl-utils \
        sed \
        patchelf \
        findutils \
        coreutils \
        bash

COPY --chmod=654 \
    ${CONTAINER_CONFIGURATION}/${CONTAINER_ENTRYPOINT} /entrypoint.sh
COPY --chmod=644 \
    ${CONTAINER_CONFIGURATION}/${APPLICATION_CONFIGURATION} /etc/krb5.conf

# Get all libraries and interpreters required by the runtime
RUN library_buffer="" && \
    # libraries
    for bin in ${RUNTIME_BINARIES}; do \
        libraries=$(ldd $(which $bin) | sed -nE ${LIB_FILTER}); \
        library_buffer="$library_buffer$libraries"$'\n'; \
    done && \
    sorted_libraries=$(echo -e "$library_buffer" | sort | uniq ) && \
    echo "$sorted_libraries" > ${LIB_BUFFER} && \
    # interpreters
    interpreter_buffer="" && \
    for bin in ${RUNTIME_BINARIES}; do \
        interpreter=$(basename \
            $(ldd $(which $bin) | sed -nE ${INTERPRETER_FILTER})); \
        interpreter_buffer="$interpreter_buffer$bin $interpreter"$'\n'; \
    done && \
    echo -e "$interpreter_buffer" > ${INTERPRETER_BUFFER} && \
    # remove empty lines - prevents patchelf --set-interpreter from failing
    sed -i '/^$/d' \
        ${LIB_BUFFER} \
        ${INTERPRETER_BUFFER}

# Switch shell to patch /bin/sh interpreter
SHELL ["/bin/bash", "-c"]

# Move krb5 client libraries to a separate directory and set the interpreter
RUN mkdir ${LIB_PATH} && \
    cat ${LIB_BUFFER} | \
        xargs -I {} cp {} ${LIB_PATH}/ && \
    while read -r bin interpreter; do \
        patchelf --set-interpreter ${LIB_PATH}/$interpreter $(which $bin); \
    done < ${INTERPRETER_BUFFER} && \
    for bin in ${RUNTIME_BINARIES}; do \
        patchelf --set-rpath ${LIB_PATH} $(which $bin); \
    done

# Create service user and group
RUN addgroup -g 65535 ${CONTAINER_USERNAME} && \
    adduser --shell /sbin/nologin \
        --disabled-password \
        --ingroup ${CONTAINER_USERNAME} ${CONTAINER_USERNAME} \
        --uid 65535 \
        no-create-home && \
    # Create service working directories
    mkdir -p \
        /krb5 \
        /etc/krb5.conf.d \
        /var/cache/krb5

FROM scratch AS filesystem

# Copy container configuration
COPY --from=base /etc/passwd /etc/passwd
COPY --from=base /etc/group /etc/group
COPY --from=base /etc/krb5.conf /etc/krb5.conf
COPY --from=base /etc/krb5.conf.d /etc/krb5.conf.d/
COPY \
    --chown=65535:65535 \
    --chmod=550 \
    --from=base \
        /entrypoint.sh \
        /entrypoint.sh
COPY \
    --chown=65535:65535 \
    --from=base \
        /krb5 \
        /krb5
COPY \
    --chown=65535:65535 \
    --from=base \
        /var/cache/krb5 \
        /var/cache/krb5

# Copy runtime binaries
COPY --from=base /usr/bin/kinit /usr/bin/kinit
COPY --from=base /usr/bin/klist /usr/bin/klist
COPY --from=base /bin/ls /bin/ls
COPY --from=base /bin/sh /bin/sh
COPY --from=base /bin/date /bin/date
COPY --from=base /bin/echo /bin/echo
COPY --from=base /bin/sleep /bin/sleep
# Copy krb5 client libraries and plugins
COPY --from=base /usr/lib/krb5-client /usr/lib/krb5-client
COPY --from=base /usr/lib/krb5 /usr/lib/krb5

FROM scratch AS image

ARG CONTAINER_USERNAME="kerberos"
ARG REFRESH_PERIOD=3600
ARG OPTIONS=""

ENV PERIOD_SECONDS=${REFRESH_PERIOD} \
    OPTIONS=${OPTIONS}

COPY --from=filesystem / /

USER ${CONTAINER_USERNAME}

VOLUME ["/krb5", "/etc/krb5.conf.d", "/var/cache/krb5"]

HEALTHCHECK --interval=15s --timeout=30s --start-period=15s --retries=3 \
    CMD ["/bin/sh", "-c", "klist || exit 1"]

ENTRYPOINT ["/entrypoint.sh"]

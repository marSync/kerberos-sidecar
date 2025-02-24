#!/bin/sh

[[ "$PERIOD_SECONDS" == "" ]] && PERIOD_SECONDS=3600

if [[ "$OPTIONS" == "" ]]; then
  if [[ -f /krb5/krb5.keytab ]]; then
    OPTIONS="-k"
    echo "*** using host keytab"
  elif [[ -f /krb5/client.keytab ]]; then
    OPTIONS="-k -i"
    echo "*** using client keytab"
  fi
fi

if [[ -z "$(ls -A /krb5)" ]]; then
  echo "*** Warning default keytab (/krb5/krb5.keytab) or default client keytab (/krb5/client.keytab) not found"
fi

while true
do
  echo "*** kinit at "+$(date -I)
   kinit -V $OPTIONS
   klist -c /var/cache/krb5/ccache 
   echo "*** Waiting for $PERIOD_SECONDS seconds"
   sleep $PERIOD_SECONDS

done
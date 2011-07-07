#!/bin/sh
# A lancer sur l'ui, sert à configurer automatiquement le cert utilisateur.
# user.sh <voms>
set -x
set -e
VOMS_HOST=$1
UI_HOST=`hostname -f`
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:$PATH"
export GLOBUS_LOCATION="/opt/globus"
export GPT_LOCATION="/opt/gpt"
echo "--> usercert toto1"
adduser toto1
su -c "$GLOBUS_LOCATION/bin/grid-cert-request" -l toto1
cd /home/toto1/.globus/
echo "--> prepare export and sign"
scp -o BatchMode=yes user* root@$VOMS_HOST:
ssh -o BatchMode=yes root@$VOMS_HOST "export GLOBUS_LOCATION='/opt/globus' && $GLOBUS_LOCATION/bin/grid-ca-sign -in usercert_request.pem -out signed.pem -passin pass:toto"
ssh -o BatchMode=yes root@$VOMS_HOST "mv signed.pem usercert.pem"
rm -rf user*
scp root@$VOMS_HOST:user* ./
chown -R toto1:toto1 /home/toto1
chmod 600 userkey.pem
exit 0

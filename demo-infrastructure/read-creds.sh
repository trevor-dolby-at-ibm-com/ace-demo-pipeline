#!/bin/bash

# Aiming for something like
# 
# Credentials:
#   jdbc:
#     tea:
#       username: "USERNAME"
#       password: "PASSWORD"
#     other:
#       username: "USERNAME1"
#       password: "PASSWORD1"
#   kafka:
#     tea:
#       username: "USERNAME2"
#       password: "PASnSWORD2"
#
# from files in subdirectories (one per Kube secret) that have contents like
#
# name tea
# type jdbc
# username USERNAME
# password PASSWORD
#
# created from Kube secrets that look like
#
# data:
#   name: dGVhCg==
#   type: amRiYwo=
#   username: VVNFUk5BTUUK
#   password: UEFTU1dPUkQK
#
# and are mounted under /app/secrets or wherever CREDSDIR points to.
#
# 


# Might not be any credentials
FirstCred=1
CredsDir=/app/secrets
if [ "$CREDSDIR" != "" ]; then
    CredsDir=${CREDSDIR}
fi

# Build up a set of files in a temporary directory, one file for
# each credential type found.
for creddir in ${CredsDir}/*; do
    # Make sure there's at least one match
    [ -e "${creddir}" ] || continue

    if [ "$FirstCred" == "1" ]; then
        FirstCred=0
	export TEMP_SECRETS_DIR=$(mktemp -d)
	mkdir -p $TEMP_SECRETS_DIR
    fi
    # find key information and create the file for this type on the first time through
    CRED_TYPE=$(cat $creddir/type)
    CRED_NAME=$(cat $creddir/name)
    export TEMP_SECRETS_FILE="${TEMP_SECRETS_DIR}/${CRED_TYPE}-snippet.yaml"
    if [ ! -e "${TEMP_SECRETS_FILE}" ]; then
	# Add the type in on the first credential of this type
	echo "  ${CRED_TYPE}:" >> ${TEMP_SECRETS_FILE}
    fi
    echo "    ${CRED_NAME}:" >> ${TEMP_SECRETS_FILE}
    # Add more fields here as needed
    CRED_USERNAME=$(cat $creddir/username)
    CRED_PASSWORD=$(cat $creddir/password)
    if [ "$CRED_USERNAME" != "" ]; then echo "      username: $CRED_USERNAME" >> ${TEMP_SECRETS_FILE}; fi
    if [ "$CRED_PASSWORD" != "" ]; then echo "      password: $CRED_PASSWORD" >> ${TEMP_SECRETS_FILE}; fi
done

# Print out the set of credentials found
if [ "$FirstCred" != "1" ]; then
    echo "---"
    echo "Credentials:"
    cat ${TEMP_SECRETS_DIR}/*.yaml
fi

# Remove copies
rm -rf ${TEMP_SECRETS_DIR}

#!/bin/bash

SOFTSHIM_DIR=$PWD/softhsm-2.6.1
OPENSSL_DIR=$PWD/openssl-1.1.1l

set -eo pipefail

echo -e "\nBuilding OpenSSL...\n"
pushd ${OPENSSL_DIR} > /dev/null

./config no-shared
make -j8

popd > /dev/null

echo -e "\nBuilding SoftHSM...\n"
pushd ${SOFTSHIM_DIR} > /dev/null

cmake -H. -Bbuild \
    -DBUILD_TESTS=ON \
    -DDISABLE_NON_PAGED_MEMORY=ON \
    -DENABLE_EDDSA=ON \
    -DWITH_CRYPTO_BACKEND=openssl \
    -DOPENSSL_ROOT_DIR=${OPENSSL_DIR} \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DENABLE_GOST=FALSE \
    -DENABLE_FIPS=FALSE

make -j8 -C build

echo -e "\nTesting SoftHSM...\n"
pushd build > /dev/null
ctest -V
popd > /dev/null

popd > /dev/null


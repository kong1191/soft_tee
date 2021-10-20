#!/bin/bash

# Using FIPS module
WITH_FIPS="FALSE"
ENABLE_FIPS_2="FALSE"
ENABLE_FIPS_3="FALSE"

USE_OPENSSL_STATIC_LIB="TRUE"
CLEAN_OUT="TRUE"

SOFTSHIM_DIR=$PWD/softhsm-2.6.1
#OPENSSL_DIR=$PWD/openssl-1.0.2u
OPENSSL_DIR=$PWD/openssl-1.1.1l
#OPENSSL_DIR=$PWD/openssl-3.0.0
#OPENSSL_FIPS_DIR=$PWD/openssl-fips-2.0.16
OUT_DIR=$PWD/out
FIPS_OUT_DIR=$OUT_DIR/fips
SSL_OUT_DIR=$OUT_DIR/ssl
SOFTHSM_BUILD_DIR=$OUT_DIR/softhsm_build

set -eo pipefail

###### OpenSSL FIPS Module 2.0 Library/Tools ######
[[ "${CLEAN_OUT}" == "TRUE" ]] && rm -rf ${FIPS_OUT_DIR}

if [[ "${ENABLE_FIPS_2}" == "TRUE" ]]; then
  echo -e "\nBuilding OpenSSL FIPS Module...\n"
  pushd ${OPENSSL_FIPS_DIR} > /dev/null
  ./config
  make
  make install INSTALLTOP="${FIPS_OUT_DIR}"
  popd
fi

###### OpenSSL Library/Tools ######
[[ "${CLEAN_OUT}" == "TRUE" ]] && rm -rf ${SSL_OUT_DIR}

pushd ${OPENSSL_DIR} > /dev/null

SSL_OPTIONS="--prefix=${SSL_OUT_DIR} --openssldir=${SSL_OUT_DIR}"
if [[ "${USE_OPENSSL_STATIC_LIB}" == "TRUE" ]]; then
  SSL_OPTIONS+=" no-shared -fPIC"
else
  SSL_OPTIONS+=" shared"
fi

if [[ "${CLEAN_OUT}" == "TRUE" ]]; then
  if [[ -e "Makefile" ]]; then
    make distclean
  fi
fi

if [[ "${ENABLE_FIPS_2}" == "TRUE" ]]; then
  echo -e "\nBuilding OpenSSL with FIPS Module 2.0...\n"
  ./config ${SSL_OPTIONS} --with-fipsdir=${FIPS_OUT_DIR}
  make depend
elif [[ "${ENABLE_FIPS_3}" == "TRUE" ]]; then
  echo -e "\nBuilding OpenSSL with FIPS Module 3.0...\n"
  ./config ${SSL_OPTIONS} fips
  make depend
else
  echo -e "\nBuilding OpenSSL...\n"
  ./config ${SSL_OPTIONS}
  make depend
fi

make -j24
#make -j24 install

popd > /dev/null


###### SoftHSM Library/Tools ######

if [[ "${WITH_FIPS}" == "TRUE" ]]; then
  export CC=${FIPS_OUT_DIR}/bin/fipsld
  export CXX="${FIPS_OUT_DIR}/bin/fipsld"
  export FIPSLD_CC=/usr/bin/cc
  export FIPSDIR=${FIPS_OUT_DIR}
  export FIPSLIBDIR=${FIPS_OUT_DIR}/lib
fi

[[ "${CLEAN_OUT}" == "TRUE" ]] && rm -rf ${SOFTHSM_BUILD_DIR}
echo -e "\nBuilding SoftHSM...\n"
pushd ${SOFTSHIM_DIR} > /dev/null

cmake --debug-trycompile \
    -H. -B${SOFTHSM_BUILD_DIR} \
    -DBUILD_TESTS=ON \
    -DDISABLE_NON_PAGED_MEMORY=ON \
    -DENABLE_EDDSA=OFF \
    -DWITH_CRYPTO_BACKEND=openssl \
    -DOPENSSL_USE_STATIC_LIBS=${USE_OPENSSL_STATIC_LIB} \
    -DOPENSSL_ROOT_DIR=${OPENSSL_DIR} \
    -DENABLE_GOST=FALSE \
    -DENABLE_FIPS=${WITH_FIPS}

make VERBOSE=1 -j24 -C ${SOFTHSM_BUILD_DIR}

echo -e "\nTesting SoftHSM...\n"
pushd ${SOFTHSM_BUILD_DIR} > /dev/null
ctest -V
popd > /dev/null

popd > /dev/null


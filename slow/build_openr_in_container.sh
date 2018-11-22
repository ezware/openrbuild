#!/bin/bash -e

#
# Copyright (c) 2014-present, Facebook, Inc.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# 2018-11-22 w05237@h3c.com, ezware@163.com
# 1. add -j for make
# 2. add fizz(dependents by wangle) and sigar (dependents by fbzmq)
# 3. remove inline indicator in sigar lib
# 4. remove boost dependent of fbzmq ResourceMonitor (which fails to build)
# 5. adjust the calling postion by dependent order
#      move libsodium before wangle
#      add fizz before wangle
#      add sigar before fbzmq
# 6. add pip install for openr py to avoid pypi mirror bypass
# 7. remove sudo (there is no sudo in ubuntu container)
#

set -ex

BUILD_DIR="$(readlink -f "$(dirname "$0")")"
export DESTDIR=""
mkdir -p "$BUILD_DIR/deps"
cd "$BUILD_DIR/deps"

NC=$(cat /proc/cpuinfo | grep "core id" | wc -l)
if ((NC < 1));then
  NC=1
fi

install_fizz() {
  pushd .
  if [[ ! -e "fizz" ]]; then
    git clone https://github.com/facebookincubator/fizz
  fi
  cd fizz/fizz
  cmake .
  make -j $NC
  make install
  ldconfig
  popd
}

install_sigar() {
 pushd .
  if [[ ! -e "sigar" ]]; then
    git clone https://github.com/hyperic/sigar
  fi
  cd sigar
  ./autogen.sh
  ./configure
  sed -i 's/ [_]*inline//' include/sigar_private.h
  make -j $NC
  make install
  ldconfig
  popd
}

find_github_hash() {
  if [[ $# -eq 1 ]]; then
    rev_file="github_hashes/$1-rev.txt"
    if [[ -f "$rev_file" ]]; then
      head -1 "$rev_file" | awk '{ print $3 }'
    fi
  fi
}

install_zstd() {
  pushd .
  if [[ ! -e "zstd" ]]; then
    git clone https://github.com/facebook/zstd
  fi
  cd zstd
  make -j $NC
  make install
  ldconfig
  popd
}

install_mstch() {
  pushd .
  if [[ ! -e "mstch" ]]; then
    git clone https://github.com/no1msd/mstch
  fi
  cd mstch
  cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-fPIC" .
  make -j $NC
  make install
  ldconfig
  popd
}

install_wangle() {
  pushd .
  if [[ ! -e "wangle" ]]; then
    git clone https://github.com/facebook/wangle
  fi
  rev=$(find_github_hash facebook/wangle)
  cd wangle/wangle
  if [[ ! -z "$rev" ]]; then
    git fetch origin
    git checkout "$rev"
  fi
  cmake \
    -DFOLLY_INCLUDE_DIR=$DESTDIR/usr/local/include \
    -DFOLLY_LIBRARY=$DESTDIR/usr/local/lib \
    -DBUILD_TESTS=OFF .
  make -j $NC
  make install
  ldconfig
  popd
}

install_libzmq() {
  pushd .
  if [[ ! -e "libzmq" ]]; then
    git clone https://github.com/zeromq/libzmq
  fi
  cd libzmq
  git fetch origin
  git checkout v4.2.2
  ./autogen.sh
  ./configure
  make -j $NC
  make install
  ldconfig
  popd
}

install_libsodium() {
  pushd .
  if [[ ! -e "libsodium" ]]; then
    git clone https://github.com/jedisct1/libsodium --branch stable
  fi
  cd libsodium
  ./autogen.sh
  ./configure
  make -j $NC
  make install
  ldconfig
  popd
}

install_folly() {
  pushd .
  if [[ ! -e "folly" ]]; then
    git clone https://github.com/facebook/folly
  fi
  rev=$(find_github_hash facebook/folly)
  cd folly/build
  if [[ ! -z "$rev" ]]; then
    git fetch origin
    git checkout "$rev"
  fi
  cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-fPIC" ..
  make -j $NC
  make install
  ldconfig
  popd
}

install_fbthrift() {
  pushd .
  if [[ ! -e "fbthrift" ]]; then
    git clone https://github.com/facebook/fbthrift
  fi
  rev=$(find_github_hash facebook/fbthrift)
  cd fbthrift/build
  if [[ ! -z "$rev" ]]; then
    git fetch origin
    git checkout "$rev"
  fi
  cmake -DBUILD_SHARED_LIBS=ON ..
  make -j $NC
  make install
  ldconfig
  cd ../thrift/lib/py
  python setup.py install
  popd
}

install_fbzmq() {
  pushd .
  if [[ ! -e "fbzmq" ]]; then
    git clone https://github.com/facebook/fbzmq.git
  fi
  rev=$(find_github_hash facebook/fbzmq)
  cd fbzmq/build
  if [[ ! -z "$rev" ]]; then
    git fetch origin
    git checkout "$rev"
  fi
  cmake \
    -DCMAKE_CXX_FLAGS="-Wno-sign-compare -Wno-unused-parameter" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DBUILD_TESTS=OFF \
    ../fbzmq/

  sed -i '/<boost\//c \ #include <stdio.h>\n#include <unistd.h>' ../fbzmq/service/resource-monitor/ResourceMonitor.cpp
  sed -i '/boost::/c \ char szProcFile[128]; \n snprintf(szProcFile, sizeof(szProcFile), \"/proc/%d\", pid_); \n if (access(szProcFile, F_OK) != 0) {' ../fbzmq/service/resource-monitor/ResourceMonitor.cpp
  
  make -j $NC
  make install
  ldconfig
  cd ../fbzmq/py
  python setup.py install
  popd
}

install_glog() {
  pushd .
  if [[ ! -e "glog" ]]; then
    git clone https://github.com/google/glog
  fi
  cd glog
  git fetch origin
  git checkout v0.3.5
  set -eu && autoreconf -i
  ./configure
  make -j $NC
  make install
  ldconfig
  popd
}

install_gflags() {
  pushd .
  if [[ ! -e "gflags" ]]; then
    git clone https://github.com/gflags/gflags
  fi
  cd gflags
  git fetch origin
  git checkout v2.2.0
  if [[ ! -e "mybuild" ]]; then
    mkdir mybuild
  fi
  cd mybuild
  cmake -DBUILD_SHARED_LIBS=ON ..
  make -j $NC
  make install
  ldconfig
  popd
}

install_gtest() {
  pushd .
  if [[ ! -e "googletest" ]]; then
    git clone https://github.com/google/googletest
  fi
  cd googletest
  git fetch origin
  git checkout release-1.8.0
  cd googletest
  cmake .
  make -j $NC
  make install
  ldconfig
  cd ../googlemock
  cmake .
  make -j $NC
  make install
  ldconfig
  popd
}

install_re2() {
  pushd .
  if [[ ! -e "re2" ]]; then
    git clone https://github.com/google/re2
  fi
  cd re2
  if [[ ! -e "mybuild" ]]; then
    mkdir mybuild
  fi
  cd mybuild
  cmake ..
  make -j $NC
  make install
  ldconfig
  popd
}


install_libnl() {
  pushd .
  if [[ ! -e "libnl" ]]; then
    git clone https://github.com/thom311/libnl
    cd libnl
    git fetch origin
    git checkout libnl3_2_25
    git apply ../../fix-route-obj-attr-list.patch
    cd ..
  fi
  cd libnl
  ./autogen.sh
  ./configure
  make -j $NC
  make install
  ldconfig
  popd
}

install_krb5() {
  pushd .
  if [[ ! -e "krb5" ]]; then
    git clone https://github.com/krb5/krb5
  fi
  cd krb5/src
  git fetch origin
  git checkout krb5-1.16.1-final
  set -eu && autoreconf -i
  ./configure
  make -j $NC
  make install
  ldconfig
  popd
}

install_openr() {
  pushd .
  cd "$BUILD_DIR"
  cmake \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTS=ON \
    -DADD_ROOT_TESTS=ON \
    -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -fPIC" \
    ../openr/
  make -j $NC
  make install
  chmod +x "/usr/local/sbin/run_openr.sh"
  cd "$BUILD_DIR/../openr/py"
  pip install cffi
  pip install future
  python setup.py build

  #avoid mirror bypass
  pip install "bunch" "click" "hexdump" "networkx" "pyzmq" "six" "tabulate" "futures" "ipaddress" "typing"

  python setup.py install
  cd "$BUILD_DIR"
  make test
  popd
}

#
# Install required tools and libraries via package managers
#
prepare() {
apt-get update
apt-get install -y libdouble-conversion-dev \
  libssl-dev \
  cmake \
  make \
  zip \
  git \
  autoconf \
  autoconf-archive \
  automake \
  libtool \
  g++ \
  libboost-all-dev \
  libevent-dev \
  flex \
  bison \
  liblz4-dev \
  liblzma-dev \
  scons \
  libsnappy-dev \
  libsasl2-dev \
  libnuma-dev \
  pkg-config \
  zlib1g-dev \
  binutils-dev \
  libjemalloc-dev \
  libiberty-dev \
  python-setuptools \
  python3-setuptools \
  python-pip
}

#
# install other dependencies from source
#
prepare
install_gflags
install_glog # Requires gflags to be build first
install_gtest
install_mstch
install_zstd
install_folly
install_libsodium
install_fizz
install_wangle
install_libzmq
install_libnl
install_krb5
install_fbthrift
install_sigar
install_fbzmq
install_re2
install_openr

echo "OpenR built and installed successfully"
exit 0

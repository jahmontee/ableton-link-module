#!/bin/sh
set -eu
case "$0" in */*) cd "${0%/*}" ;; esac
test -d build || mkdir -p build
cxx=${CXX:-aarch64-linux-gnu-g++-12}
compile() {
    "$cxx" -std=c++17 -O2 -fno-fast-math -Wall -Wextra -Werror -pthread \
        -Iengine-source -Ivendor/lv2-headers -fPIC -shared "$@"
}
compile engine-source/plugin.cpp -latomic -o build/engine.so
compile admission-source/network_gate.cpp -ldl -o build/module.so

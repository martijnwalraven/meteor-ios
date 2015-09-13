#!/bin/sh

BUILD_VERSION=$(git rev-list master --count)
agvtool new-version $BUILD_VERSION

#!/bin/sh

VERSION=$(<VERSION)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "${PROJECT_DIR}/${INFOPLIST_FILE}"

BUILD_VERSION=$(git rev-list master --count)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "${PROJECT_DIR}/${INFOPLIST_FILE}"

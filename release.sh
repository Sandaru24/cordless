#!/bin/bash

#
# This tiny script helps me not to mess up the procedure of releasing a new
# version of cordless.
#
# Dependencies:
#   * sha256sum
#   * envsubst
#   * snapcraft
#   * git
#   * date
#   * go
#   * xclip
#

#
# This will cause a script failure in case any of the commands below fail.
#

set -e

#
# Define executable names for later usage.
#

BIN_LINUX="cordless_linux_64"
BIN_DARWIN="cordless_darwin"
BIN_WINDOWS="cordless.exe"

#
# Building cordless for darwin, linux and windows.
#

GOOS=linux go build -o $BIN_LINUX
GOOS=darwin go build -o $BIN_DARAWIN
GOOS=windows go build -o $BIN_WINDOWS

#
# Setup environment variables.
#
# RELEASE_DATE is the current date in format Year-Month-Day, since cordless
# uses dates for versioning.
#
# EXE_HASH is sha256 of the previously built cordless.exe and is required
# for scoop to properly work.
#
# Since envsubst can not see the unexported variables, we export them here
# and unexport them at a later point and time.
#

export RELEASE_DATE="$(date +%Y-%m-%d)"
export EXE_HASH="$(sha256sum ./$BIN_WINDOWS | cut -f 1 -d " ")"

#
# Substituting the variables in the scoop manifest tempalte into the actual
# manifest.
#

envsubst < cordless.json_template > cordless.json

#
# Commit and push the new scoop manifest
#

git commit cordless.json -m "Bump scoop package to version $RELEASE_DATE"
git push

#
# Create a new tag and push it.
#

git tag -s $RELEASE_DATE -m "Update scoop package to version $RELEASE_DATE"
git push --tags

#
# Build and push the snap package.
#
# It is important that this happens after pusing the tag, because otherwise
# the version of the built snap package will end up being `DATE_dirty`.
#

snapcraft clean cordless -s pull
snapcraft
snapcraft push "cordless_${RELEASE_DATE}_amd64.snap"

#
# Copies the changelog for pasting into the github release. The changes will
# include all commits between the latest and the previous tag.
#

RELEASE_BODY="$(git log --pretty=oneline --abbrev-commit $(git describe --abbrev=0 $(git describe --abbrev=0)^)..$(git describe --abbrev=0))"

hub release edit -a $BIN_LUNUX -a $BIN_DAWIN -a $BIN_WINDOWS -m "" -m "${RELEASE_BODY}" $RELEASE_DATE

#
# Unsetting(and unexporting) previously exported environment variables.
#

unset RELEASE_DATE
unset EXE_HASH
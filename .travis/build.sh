#!/bin/sh

# Discern whether this is a release build.
if [ "$TRAVIS_SECURE_ENV_VARS" = true \
  -a "$TRAVIS_PULL_REQUEST" = false ]
then
  echo '--> Release build detected. Will upload it to the update site.'
  UPLOAD_TO_UPDATE_SITE=true
fi

UPLOAD_TO_UPDATE_SITE=true

# Perform the main build.
curl -fsLO https://raw.githubusercontent.com/scijava/scijava-scripts/master/travis-build.sh &&
sh travis-build.sh &&
# TODO note that travis-build.sh takes gpg signing keys, but we dont have them yet

# Upload release version to the ImageJ update site.
if [ "$UPLOAD_TO_UPDATE_SITE" ]
then
  sh deploy.sh
else
  echo '--> Not a release build; skipping upload to update site.'
fi

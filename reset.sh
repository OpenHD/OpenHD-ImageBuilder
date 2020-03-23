#!/bin/bash -e

pushd stages
find . -type f -name 'SKIP' -delete
find . -type f -name 'SKIP_STEP*' -delete
find . -type f -name 'SKIP_CH_STEP*' -delete
popd

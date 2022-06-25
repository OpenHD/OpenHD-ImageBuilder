#!/bin/bash
./build.sh $1 $2 $3 |& tee buildlog.log

#Just a file for writing logs while building
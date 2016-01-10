#!/bin/bash
make all
perlcritic --severity 2 --verbose 7 src/lib

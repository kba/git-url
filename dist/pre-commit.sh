#!/bin/bash
make all
perlcritic --verbose 8 --severity 4 bin/git-url

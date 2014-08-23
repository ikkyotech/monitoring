#!/bin/bash
OLD_DIR=$( pwd )
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/test
cat init | sudo bash
cd $OLD_DIR
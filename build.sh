#!/bin/bash

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PROJECT="$1"
if [ -z "$DIR/$PROJECT" ]; then
	echo "Usage: $0 <project_name>"
	exit 1
fi

source "$DIR/$PROJECT.conf"

HOOKS_DIR="$DIR/hooks/$PROJECT"
WORKSPACE=$(readlink -f "$WORKSPACE")

cd "$WORKSPACE"

if [ -e "$HOOKS_DIR/beforeAll.sh" ]; then
	. "$HOOKS_DIR/beforeAll.sh"
fi

rm -rf "$PROJECT/src"
mkdir -p "$PROJECT"
cd "$PROJECT"
git clone "$GIT_REMOTE" src
cd src
git checkout "$BRANCH"
git pull
if [ -e "$HOOKS_DIR/afterPull.sh" ]; then
	. "$HOOKS_DIR/afterPull.sh"
fi

cd "$WORKSPACE/$PROJECT"
DATE=$(date +%Y%m%d)
DEST_DIR=archives/$DATE
rm -rf $DEST_DIR
mkdir -p $DEST_DIR
find 'src/build/' -maxdepth 1 -type d -name '*linux*' | while read BUILD_DIR
do
  tar -C "$BUILD_DIR/.." -czf "$DEST_DIR/$(basename $BUILD_DIR).tar.gz" "$(basename $BUILD_DIR)"
done

find 'src/build/' -mindepth 1 -maxdepth 1 -type d -not -name '*linux*' | while read BUILD_DIR
do
  FILE_NAME=$(basename $BUILD_DIR)
  (cd "$BUILD_DIR/.." && zip -qr - $FILE_NAME) > "$DEST_DIR/$FILE_NAME.zip"
done

rm -f archives/latest 
ln -s "$(readlink -f $DEST_DIR)" "$(readlink -f archives/latest)"

# Delete folders older than $ARCHIVES_RETENTION days
find archives/* -mindepth 0 -maxdepth 0 -type d -mtime +"$ARCHIVES_RETENTION" -exec rm -rf {} \;

if [ -e "$HOOKS_DIR/afterAll.sh" ]; then
	. "$HOOKS_DIR/afterAll.sh"
fi

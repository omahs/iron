#!/bin/bash -ue


#
# defaults
#
target=chrome

#
# parse args
#
VALID_ARGS=$(getopt -o t:h --long target:,help -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -t | --target)
        target=$2
        shift 2
        ;;
    -h | --help)
        echo "help"
        shift
        ;;
    --) shift; 
        break 
        ;;
  esac
done

#
# building
#

export NODE_ENV=production
export DIST_DIR=./dist/$target
rm -rf $DIST_DIR

version=$(cat ../Cargo.toml | grep -E "^version" | cut -d'"' -f 2)
basename=$target-v$version

yarn run vite build --config vite/base.ts
yarn run vite build --config vite/content.ts
yarn run vite build --config vite/inpage.ts
yarn run vite build --config vite/background.ts

# choose manifest
mv $DIST_DIR/manifest-$target.json $DIST_DIR/manifest.json
rm $DIST_DIR/manifest-*.json
sed -i 's/%VERSION%/'$version'/g' $DIST_DIR/manifest.json

# create zip
(cd $DIST_DIR && zip -r ../$basename.zip .)

# create crx / xpi
case $target in
  # builds and publishes to the chrome extension store
  chrome)
    yarn run crx pack $DIST_DIR -o ./dist/chrome-v$version.crx
    ;;

  # builds and publishes to the firefox extension store
  firefox)
    yarn run web-ext build -s $DIST_DIR -a .
    mv ./iron_wallet-$version.zip dist/firefox-v$version.xpi
    ;;
esac

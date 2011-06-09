#!/usr/bin/env bash

# Copyright (C) 2010 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script auto-generates the scripts that manage the handling of the
# proprietary blobs necessary to build the Android Open-Source Project code
# for passion and crespo targets

# It needs to be run from the root of a source tree that can repo sync,
# runs builds with and without the vendor tree, and uses the difference
# to generate the scripts.

# It can optionally upload the results to a Gerrit server for review.

# WARNING: It destroys the source tree. Don't leave anything precious there.

# Caveat: this script does many full builds (2 per device). It takes a while
# to run. It's best # suited for overnight runs on multi-CPU machines
# with a lot of RAM.

# Syntax: device/common/generate-blob-scripts.sh -f|--force [<server> <branch>]
#
# If the server and branch paramters are both present, the script will upload
# new files (if there's been any change) to the mentioned Gerrit server,
# in the specified branch.

if test "$1" != "-f" -a "$1" != "--force"
then
  echo This script must be run with the --force option
  exit 1
fi
shift

DEVICES="crespo crespo4g stingray wingray tuna toro panda"

ARCHIVEDIR=archive-$(date +%s)
mkdir $ARCHIVEDIR

repo sync
repo sync
repo sync

. build/envsetup.sh
for DEVICENAME in $DEVICES
do
  rm -rf out
  lunch full_$DEVICENAME-user
  make -j32
  cat out/target/product/$DEVICENAME/installed-files.txt |
    cut -b 15- |
    sort -f > $ARCHIVEDIR/$DEVICENAME-with.txt
done
rm -rf vendor
for DEVICENAME in $DEVICES
do
  rm -rf out
  lunch full_$DEVICENAME-user
  make -j32
  cat out/target/product/$DEVICENAME/installed-files.txt |
    cut -b 15- |
    sort -f > $ARCHIVEDIR/$DEVICENAME-without.txt
done

for DEVICENAME in $DEVICES
do
  MANUFACTURERNAME=$( find device -type d | grep [^/]\*/[^/]\*/$DEVICENAME\$ | cut -f 2 -d / )
  for FILESTYLE in extract unzip
  do
    (
    echo '#!/bin/sh'
    echo
    echo '# Copyright (C) 2010 The Android Open Source Project'
    echo '#'
    echo '# Licensed under the Apache License, Version 2.0 (the "License");'
    echo '# you may not use this file except in compliance with the License.'
    echo '# You may obtain a copy of the License at'
    echo '#'
    echo '#      http://www.apache.org/licenses/LICENSE-2.0'
    echo '#'
    echo '# Unless required by applicable law or agreed to in writing, software'
    echo '# distributed under the License is distributed on an "AS IS" BASIS,'
    echo '# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'
    echo '# See the License for the specific language governing permissions and'
    echo '# limitations under the License.'
    echo
    echo '# This file is generated by device/common/generate-blob-scripts.sh - DO NOT EDIT'
    echo
    echo DEVICE=$DEVICENAME
    echo MANUFACTURER=$MANUFACTURERNAME
    echo
    echo 'mkdir -p ../../../vendor/$MANUFACTURER/$DEVICE/proprietary'

    diff $ARCHIVEDIR/$DEVICENAME-without.txt $ARCHIVEDIR/$DEVICENAME-with.txt |
      grep -v '\.odex$' |
      grep '>' |
      cut -b 3- |
      while read FULLPATH
      do
        if test $FILESTYLE = extract
        then
          echo adb pull $FULLPATH ../../../vendor/\$MANUFACTURER/\$DEVICE/proprietary/$(basename $FULLPATH)
        else
          echo unzip -j -o ../../../\${DEVICE}_update.zip $(echo $FULLPATH | cut -b 2-) -d ../../../vendor/\$MANUFACTURER/\$DEVICE/proprietary
        fi
        if test $(basename $FULLPATH) = akmd -o $(basename $FULLPATH) = mm-venc-omx-test -o $(basename $FULLPATH) = parse_radio_log -o $(basename $FULLPATH) = akmd8973 -o $(basename $FULLPATH) = gpsd -o $(basename $FULLPATH) = pvrsrvinit
        then
          echo chmod 755 ../../../vendor/\$MANUFACTURER/\$DEVICE/proprietary/$(basename $FULLPATH)
        fi
      done
    echo

    echo -n '(cat << EOF) | sed s/__DEVICE__/$DEVICE/g | sed s/__MANUFACTURER__/$MANUFACTURER/g > ../../../vendor/$MANUFACTURER/$DEVICE/'
    echo 'device-vendor-blobs.mk'

    echo '# Copyright (C) 2010 The Android Open Source Project'
    echo '#'
    echo '# Licensed under the Apache License, Version 2.0 (the "License");'
    echo '# you may not use this file except in compliance with the License.'
    echo '# You may obtain a copy of the License at'
    echo '#'
    echo '#      http://www.apache.org/licenses/LICENSE-2.0'
    echo '#'
    echo '# Unless required by applicable law or agreed to in writing, software'
    echo '# distributed under the License is distributed on an "AS IS" BASIS,'
    echo '# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.'
    echo '# See the License for the specific language governing permissions and'
    echo '# limitations under the License.'
    echo
    echo -n '# This file is generated by device/__MANUFACTURER__/__DEVICE__/'
    echo -n $FILESTYLE
    echo '-files.sh - DO NOT EDIT'

    FOUND=false
    diff $ARCHIVEDIR/$DEVICENAME-without.txt $ARCHIVEDIR/$DEVICENAME-with.txt |
      grep -v '\.odex$' |
      grep '>' |
      cut -b 3- |
      while read FULLPATH
      do
        if test $(basename $FULLPATH) = libgps.so -o $(basename $FULLPATH) = libcamera.so -o $(basename $FULLPATH) = libsecril-client.so
        then
          if test $FOUND = false
          then
            echo
            echo '# Prebuilt libraries that are needed to build open-source libraries'
            echo 'PRODUCT_COPY_FILES := \\'
          else
            echo \ \\\\
          fi
          FOUND=true
          echo -n \ \ \ \ vendor/__MANUFACTURER__/__DEVICE__/proprietary/$(basename $FULLPATH):obj/lib/$(basename $FULLPATH)
        fi
      done
    echo

    FOUND=false
    diff $ARCHIVEDIR/$DEVICENAME-without.txt $ARCHIVEDIR/$DEVICENAME-with.txt |
      grep -v '\.odex$' |
      grep -v '\.apk$' |
      grep '>' |
      cut -b 3- |
      while read FULLPATH
      do
        if test $FOUND = false
        then
          echo
          echo -n '# All the blobs necessary for '
          echo $DEVICENAME
          echo 'PRODUCT_COPY_FILES += \\'
        else
          echo \ \\\\
        fi
        FOUND=true
        echo -n \ \ \ \ vendor/__MANUFACTURER__/__DEVICE__/proprietary/$(basename $FULLPATH):$(echo $FULLPATH | cut -b 2-)
      done
    echo
    echo 'EOF'
    echo
    echo './setup-makefiles.sh'

    ) > $ARCHIVEDIR/$DEVICENAME-$FILESTYLE-files.sh
    cp $ARCHIVEDIR/$DEVICENAME-$FILESTYLE-files.sh device/$MANUFACTURERNAME/$DEVICENAME/$FILESTYLE-files.sh
    chmod a+x device/$MANUFACTURERNAME/$DEVICENAME/$FILESTYLE-files.sh
  done

  (
    cd device/$MANUFACTURERNAME/$DEVICENAME
    git add .
    git commit -m "auto-generated blob-handling scripts"
    if test "$1" != "" -a "$2" != ""
    then
      echo uploading to server $1 branch $2
      git push ssh://$1:29418/device/$MANUFACTURERNAME/$DEVICENAME.git HEAD:refs/for/$2
    fi
  )

done

echo * device/* |
  tr \  \\n |
  grep -v ^archive- |
  grep -v ^device$ |
  grep -v ^device/common$ |
  xargs rm -rf

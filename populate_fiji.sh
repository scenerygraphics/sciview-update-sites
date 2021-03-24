#!/bin/sh

#
# populate_fiji.sh
#
# This script generates a local Fiji.app with SciView installed.

update_site_name="sciview-ageratum"

# -- Functions --

left() { echo "${1%$2*}"; }
right() { echo "${1##*$2}"; }
mid() { right "$(left "$1" "$3")" "$2"; }

die() {
  echo "$@" 1>&2
  exit 1
}

# Copies the given Maven coordinate to the specified output directory.
install() {
  (set -x; mvn dependency:copy -Dartifact="$1" -DoutputDirectory="$2" > /dev/null) ||
    die "Install failed"
}

# Copies the given Maven coordinate to the specified output directory, keeping the groupId
installWithGroupId() {
  (set -x; mvn dependency:copy -Dartifact="$1" -DoutputDirectory="$2" -Dmdep.prependGroupId=true > /dev/null) ||
    die "Install failed"
}

# Deletes the natives JAR with the given artifactId and classifier.
deleteNative() {
  (set -x; rm -f $FijiDirectory/jars/$1-[0-9]*-$2.jar $FijiDirectory/jars/*/$1-[0-9]*-$2.jar) ||
    die "Delete failed"
}

# Deletes all natives JARs with the given artifactId.
deleteNatives() {
  (set -x; rm -f $FijiDirectory/jars/$1-[0-9]*-natives-*.jar $FijiDirectory/jars/*/$1-[0-9]*-natives-*.jar) ||
    die "Delete failed"
}

# -- Check if we have a path given, in that case we do not download a new Fiji, but use the path given --
if [ -z "$1" ]
then
    echo "--> Installing into pristine Fiji installation"
    echo "--> If you want to install into a pre-existing Fiji installation, run as"
    echo "     $0 path/to/Fiji.app"
    # -- Determine correct ImageJ launcher executable --
    
    case "$(uname -s),$(uname -m)" in
      Linux,x86_64) launcher=ImageJ-linux64 ;;
      Linux,*) launcher=ImageJ-linux32 ;;
      Darwin,*) launcher=Contents/MacOS/ImageJ-macosx ;;
      MING*,*) launcher=ImageJ-win32.exe ;;
      *) die "Unknown platform" ;;
    esac
    
    # -- Roll out a fresh Fiji --
    
    if [ ! -f fiji-nojre.zip ]
    then
      echo
      echo "--> Downloading Fiji"
      curl -L -O https://downloads.imagej.net/fiji/latest/fiji-nojre.zip || 
          die "Could not download Fiji"
    fi
    
    echo "--> Unpacking Fiji"
    rm -rf Fiji.app
    unzip fiji-nojre.zip || die "Could not unpack Fiji"
    
    echo
    echo "--> Updating Fiji"
    Fiji.app/$launcher --update update-force-pristine
    FijiDirectory=Fiji.app
else
    echo "--> Installing into Fiji installation at $1"
    FijiDirectory=$1
fi

echo
echo "--> Copying dependencies into Fiji installation"
#(set -x; mvn -Dimagej.app.directory=$FijiDirectory)
(set -x; mvn scijava:populate-app -Dscijava.app.directory=$FijiDirectory)

echo "--> Removing slf4j bindings"
(set -x; rm -f $FijiDirectory/jars/slf4j-simple-*.jar)

echo "--> Removing old joml"
(set -x; rm -f $FijiDirectory/jars/joml-1.9.24.jar)

ls $FijiDirectory/jars

# -- Now that we populated fiji, let's double check that it works --

echo
echo "--> Installing SciView-Unstable update site for testing"
Fiji.app/$launcher --update add-update-site $update_site_name https://sites.imagej.net/$update_site_name/
Fiji.app/$launcher --update update

echo
echo "--> Testing installation with command: sc.iview.commands.help.About"
OUT_TEST=$(Fiji.app/$launcher  --headless --run sc.iview.commands.help.About)
echo $OUT_TEST

if [ -z "$OUT_TEST" ]
then
    echo "Test failed"
    exit 1
else
    echo "Test passed"
fi

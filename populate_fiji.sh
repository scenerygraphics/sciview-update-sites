#!/bin/sh

#
# populate_fiji.sh
#
# This script generates a local Fiji.app with SciView installed.

update_site_name="sciview-buttercup"

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

echo "--> Removing old Trainable_Segmentation because of imagescience.jar removal"
(set -x; rm -f $FijiDirectory/plugins/Trainable_Segmentation-*)

echo "--> Removing ffmpeg* because we are adding our ffmpegs and their natives separately"
(set -x; rm -f $FijiDirectory/jars/ffmpeg*)

echo "--> Removing kotlinx-coroutines-core-1.3.8.jar because it is outdated"
(set -x; rm -f $FijiDirectory/jars/kotlinx-coroutines-core-1.3.8.jar)

echo "--> Fetching correct ImageJ-linux64 launcher"
wget https://maven.scijava.org/service/local/repositories/snapshots/content/net/imagej/imagej-launcher/6.0.3-SNAPSHOT/imagej-launcher-6.0.3-20201117.205912-15-linux64.exe -O $FijiDirectory/ImageJ-linux64
chmod +x ImageJ-linux64


# -- Handle natives

# -- Put back jar/gluegen-rt and jar/jogl-all --
echo
echo "--> Reinstalling gluegen-rt, jogl-all, jocl, jinput, and ffmpeg"
gluegenJar=$(echo $FijiDirectory/jars/gluegen-rt-main-*.jar)
gluegenVersion=$(mid "$gluegenJar" "-" ".jar")
install "org.jogamp.gluegen:gluegen-rt:$gluegenVersion" $FijiDirectory/jars

joglJar=$(echo $FijiDirectory/jars/jogl-all-main-*.jar)
joglVersion=$(mid "$joglJar" "-" ".jar")
install "org.jogamp.jogl:jogl-all:$joglVersion" $FijiDirectory/jars

joclGAV=$(mvn dependency:tree | grep jocl | awk -e '{print $NF}' | cut -d: -f1-4 | sed 's/:jar//g')
installWithGroupId "$joclGAV" $FijiDirectory/jars

jinputGAV=$(mvn dependency:tree | grep jinput | head -n1 | awk -e '{print $NF}' | cut -d: -f1-4 | sed 's/:jar//g' | sed 's/:compile//g')
install "$jinputGAV" $FijiDirectory/jars
installWithGroupId "$jinputGAV:jar:natives-all" $FijiDirectory/jars/win64
installWithGroupId "$jinputGAV:jar:natives-all" $FijiDirectory/jars/linux64
installWithGroupId "$jinputGAV:jar:natives-all" $FijiDirectory/jars/macosx
echo "--> Removing jinput natives from JAR root"
(set -x; rm -f $FijiDirectory/jars/jinput-*-natives-all.jar)

ffmpegGAV=$(mvn dependency:tree | grep 'ffmpeg:jar' | head -n1 | awk -e '{print $NF}' | cut -d: -f1-4 | sed 's/:jar//g' | sed 's/:compile//g')
installWithGroupId "$ffmpegGAV" $FijiDirectory/jars
installWithGroupId "$ffmpegGAV:jar:windows-x86_64" $FijiDirectory/jars/win64
installWithGroupId "$ffmpegGAV:jar:linux-x86_64" $FijiDirectory/jars/linux64
installWithGroupId "$ffmpegGAV:jar:macosx-x86_64" $FijiDirectory/jars/macosx

# -- Fix old miglayout 

#rm $FijiDirectory/jars/miglayout-3.7.4-swing.jar
#install "com.miglayout:miglayout-swing:5.2" $FijiDirectory/jars

# -- Fix imagej-mesh versions with jitpack version clashing (temporary)

rm $FijiDirectory/jars/imagej-mesh-*
install "net.imagej:imagej-mesh:0.8.1" $FijiDirectory/jars

# -- Get the list of native libraries --


# [NB] dependency:list emits G:A:P:C:V but dependency:copy needs G:A:V:P:C.
echo
echo "--> Extracting list of native dependencies"
natives=$(mvn -B dependency:list |
  grep natives |
  sed -e 's/^\[INFO\] *\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):.*/\1:\2:\5:\3:\4/' |
  grep -v -- '-\(android\|armv6\|solaris\)' |
  sort)
for gavpc in $natives
do
  gavp=$(left "$gavpc" ':')
  gav=$(left "$gavp" ':')
  ga=$(left "$gav" ':')
  g=$(left "$ga" ':')
  a=$(right "$ga" ':')
  v=$(right "$gav" ':')
  p=$(right "$gavp" ':')
  c=$(right "$gavpc" ':')
  echo
  echo "[$a-$v-$c]"
  case "$g" in
    org.lwjgl|graphics.scenery)
      deleteNatives "$a"
      # [NB] Install all architectures manually; only one is a dependency.
      install "$gavp:natives-windows" $FijiDirectory/jars/win64
      install "$gavp:natives-macos" $FijiDirectory/jars/macosx
      install "$gavp:natives-linux" $FijiDirectory/jars/linux64
      ;;
    *)
      deleteNative "$a" "$c"
      case "$c" in
        natives-win*-i586) continue ;;
        natives-win*) platform=win64 ;;
        natives-linux*-i586) continue ;;
        natives-linux*) platform=linux64 ;;
        natives-osx|natives-mac*) platform=macosx ;;
        natives-all*) continue ;;
        *) die "Unsupported platform: $c" ;;
      esac
      install "$gavpc" "$FijiDirectory/jars/$platform"
      ;;
  esac
done

# -- Show the contents of the jars directory after we make all the adjustments

ls -R $FijiDirectory/jars

# -- Now that we populated fiji, let's double check that it works --

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

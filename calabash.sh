#!/bin/bash
cygwin=false;
mingw=false;
case "`uname`" in
  CYGWIN*) cygwin=true;;
  MINGW*) mingw=true;;
esac

export JAVA=java

JAVA_VERSION=$(java -version 2>&1 | sed -n ';s/.* version "\(.*\)\..*\..*\..*".*/\1/p;')
if [ -z "$JAVA_VERSION" ]; then
    JAVA_VERSION=$(java -version 2>&1 | sed -n ';s/.* version ".*\.\(.*\)\..*".*/\1/p;')
fi

# readlink -f is unavailable on Mac OS X
function real_dir() {
    SOURCE="$1"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd  )"
}

function mingw_win_path() {
    SOURCE="$1"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$(readlink "$SOURCE")"
	[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd -W )/$( basename "$SOURCE" )"
}

DIR="$( real_dir "${BASH_SOURCE[0]}" )"

EXT_BASE=$DIR/extensions
CALABASH_VERSION=3.0.30
DISTRO="$DIR/distro"

if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$( real_dir "$DIR" )
fi

# if it doesn't exist, set it to the current canonical name:
if [ ! -d $ADAPTATIONS_DIR ]; then
    ADAPTATIONS_DIR="$PROJECT_DIR/a9s"
fi
if [ -z $LOCALDEFS ]; then
    LOCALDEFS="$ADAPTATIONS_DIR/common/calabash/localdefs.sh"
fi

if [ -f "$LOCALDEFS" ]; then
  echo Using local Calabash settings file "$LOCALDEFS" >&2
  source "$LOCALDEFS"
fi

# If you want to use Saxon PE or EE, you'll have to provide an xproc configuration called config.xml in a calabash directory
# or as an environment variable CFG. You also need to prepend the directory that contains
# saxon-license.lic to CLASSPATH or add it to a saxon configuration as 
# <configuration xmlns="http://saxon.sf.net/ns/configuration" licenseFileLocation="path-to-license/saxon-license.lic" 
# The saxon configuration can be invoked via specifying it in the claabash config as @saxon-configuration in root element of <cc:xml-calabash>. 
# Alternatively, particularly if your project also requires a standalone saxon, you may include
# https://subversion.le-tex.de/common/saxon-pe96/ or another repo that contains Saxon EE as an external,
# mounted to $PROJECT_DIR/saxon/ (convention over configuration).
# Since this Saxon PE repo is public, the license file has to be supplied by different means.
# Supposing that $ADAPTATIONS_DIR/common/saxon/ stems from a privately hosted repo, it is added
# to CLASSPATH by default, expecting saxon-license.lic to reside there.

# if Saxon PE or EE: use a config. Also if a config is given.

if [ -z $CFG ]; then
    CFG=$DIR/config.xml
fi

# SAXON_JAR is the path to a Saxon PE or EE jar file. Its name should match the following
# regex: /[ehp]e\.jar$/ so that we can extract the substring 'ee', 'he', or 'pe':
if [ -z $SAXON_JAR ]; then
	if [ -e $PROJECT_DIR/saxon/saxon-pe-12.7.jar ]; then
		SAXON_JAR=$PROJECT_DIR/saxon/saxon-pe-12.7.jar
    elif [ -e $PROJECT_DIR/saxon/saxon10ee.jar ]; then
		SAXON_JAR=$PROJECT_DIR/saxon/saxon10ee.jar
    elif [ -e $PROJECT_DIR/saxon/saxon10pe.jar ]; then
        SAXON_JAR=$PROJECT_DIR/saxon/saxon10pe.jar
    elif [ -e $DIR/saxon/saxon-pe-12.7.jar ]; then
        SAXON_JAR=$DIR/saxon/saxon-pe-12.7.jar
    else
	SAXON_JAR=$DISTRO/lib/Saxon-HE-12.8.jar
    fi
fi

if [ -z $HEAP ]; then
    HEAP=1024m
fi

if [ -z $JAVA_FILE_ENCODING ]; then
    JAVA_FILE_ENCODING=UTF8
fi

if [ -z $ENTITYEXPANSIONLIMIT ]; then
    # 2**31 - 1
    # Set to 0 if unlimited, JVM default is probably 64000.
    # Applies only to source documents with many character entity references.
    ENTITYEXPANSIONLIMIT=2147483647
fi

if [ -z $UI_LANG ]; then
    UI_LANG=en
fi

jarsArray=()
if [ -d "$DISTRO/extra" ]; then
    for jar in "$DISTRO/extra"/*.jar; do
        jarsArray+=( "$jar" )
    done
fi

for jar in "$DISTRO/lib"/*.jar; do
    jarsArray+=( "$jar" )
done

CP="$DISTRO/xmlcalabash-app-$CALABASH_VERSION.jar:$DISTRO/app-sources.jar:$SAXON_JAR"

for ((idx = 0; idx < ${#jarsArray[@]}; idx++)); do
    CP="$CP:${jarsArray[$idx]}"
done

OSDIR=$DIR
if $cygwin; then
  CP=$(cygpath -map "$CP")
  EXT_BASE=$(cygpath -ma "$EXT_BASE")
  CFG=$(cygpath -ma "$CFG")
  PROJECT_DIR=file:/$(cygpath -ma "$PROJECT_DIR")
  OSDIR=$(cygpath -ma "$DIR")
  DIR=file:///"$OSDIR"
  JAVA_HOME=$(cygpath -map "$JAVA_HOME")
fi

# CATALOGS are always semicolon-separated, see 
# https://github.com/ndw/xmlresolver/blob/e1ea653ae8a98c8a46b7ad017ebd18ea1d2e8fac/src/org/xmlresolver/Configuration.java#L26
CATALOGS="$CATALOGS;$DIR/xmlcatalog/catalog.xml;$PROJECT_DIR/xmlcatalog/catalog.xml;$PROJECT_DIR/a9s/common/calabash/catalog.xml"
# In principle, $DIR/xmlcatalog/catalog.xml should be sufficient since it includes the $PROJECT_DIR catalogs via nextCatalog.
# If, however, this calabash dir is not a subdir of $PROJECT_DIR, then it makes sense to explicitly include them here.
# Please note that it is _essential_ that your project contains an xmlcatalog/catalog.xml that includes the catalogs
# of all transpect modules that you use.
if $mingw; then
  CATALOGS=file:///$(mingw_win_path "$DIR/xmlcatalog/catalog.xml")
fi

JAVA_OPTS="-Dfile.encoding=$JAVA_FILE_ENCODING -Dxml.catalog.files=$CATALOGS \
-Djruby.compile.mode=OFF \
-Dxml.catalog.staticCatalog=1 \
-Djdk.xml.entityExpansionLimit=$ENTITYEXPANSIONLIMIT \
-Duser.language=$UI_LANG \
-Dxml.catalog.cacheUnderHome \
$SYSPROPS \
-Xmx$HEAP -Xss1024k "

if [ $JAVA_VERSION -gt 11 ]; then
JAVA_OPTS+="--add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED"
fi

ADD_CFG="-c:$CFG"

# show variables for debugging
if [ "$DEBUG" == "yes" ]; then
       echo "CLASSPATH: $CP"
	   echo "PROJECT_DIR: $PROJECT_DIR"
       echo "SAXON_PROCESSOR: $SAXON_PROCESSOR"
       echo "XPROC-CONFIG: $CFG"
       echo "DIR: $DIR"
       echo "CATALOGS: $CATALOGS"
       echo "LOCALDEFS: $LOCALDEFS"
       echo "ENTITYEXPANSIONLIMIT: $ENTITYEXPANSIONLIMIT"
       echo "SAXON_JAR: $SAXON_JAR"
       echo "JAVA_OPTS: $JAVA_OPTS"
	   echo "JAVA: $JAVA"
	   echo "CFG: $CFG"
fi

$JAVA \
    -cp "$CP" \
	$JAVA_OPTS \
	com.xmlcalabash.app.Main \
	$ADD_CFG \
	"$@"

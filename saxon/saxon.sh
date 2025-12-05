#!/bin/bash
cygwin=false;
case "`uname`" in
  CYGWIN*) cygwin=true;
esac

READER=org.xmlresolver.tools.ResolvingXMLReader

if [ -z $HEAP ]; then
    HEAP=4000m
fi

if [ -z $STACK ]; then
    STACK=2m
fi

if [ -z $ENTITYEXPANSIONLIMIT ]; then
    # 2**31 - 1
    # Set to 0 if unlimited, JVM default is probably 64000.
    # Applies only to source documents with many character entity references.
    ENTITYEXPANSIONLIMIT=2147483647
fi

DIR="$( cd -P "$(dirname $( readlink -f "${BASH_SOURCE[0]}" ))" && pwd )"
CWD="$(pwd)"
CLASSPATH="${DIR}/saxon-pe-12.7.jar:${DIR}/lib/htmlparser-1.4.jar:${DIR}/lib/xmlresolver-6.0.17.jar:${DIR}/lib/xmlresolver-6.0.17-data.jar:${DIR}/:$CLASSPATH"

if $cygwin; then
  CLASSPATH=$(cygpath -map $CLASSPATH)
  DIR=file:/$(cygpath -ma "$DIR")
  CWD=file:/$(cygpath -ma "$CWD")
  CATALOG="${CWD}/xmlcatalog/catalog.xml"
fi

if [ -z $CATALOG ]; then
    CATALOG=$(readlink -f "${DIR}/../xmlcatalog/catalog.xml")
fi

if [ $CATALOG ]; then
    CATALOG_PARAM=-catalog:"${CATALOG}"
fi


echo "${CATALOG}"

java \
   -cp "${CLASSPATH}" \
   -Djdk.xml.entityExpansionLimit=$ENTITYEXPANSIONLIMIT \
   -Dxml.catalog.files=${CATALOG} \
   -Dfile.encoding=UTF8 \
   -Xmx$HEAP -Xss$STACK \
   com.saxonica.Transform \
   ${CATALOG_PARAM} \
   -x:$READER \
   -y:$READER \
   -strip:ignorable \
   -expand:off \
   -l \
   -u \
   -opt:10 \
   "$@"


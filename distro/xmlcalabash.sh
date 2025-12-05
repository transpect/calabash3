#!/bin/bash

# This is a fairly naive shell script that constructs a classpath for
# running XML Calabash. The idea is that it puts jar files from the
# "extra" directory ahead of jar files from the "lib" directory.
# This should support overriding jars. And supports running steps
# that require extra libraries.

# Try to be careful about paths with spaces in them!

# Earlier versions of this script relied on readlink -f which is not
# POSIX compliant. I never saw it fail, but I grabbed this putatively
# POSIX-compliant version from https://github.com/ko1nksm/readlinkf

readlinkf_posix() {
  [ "${1:-}" ] || return 1
  max_symlinks=40
  CDPATH='' # to avoid changing to an unexpected directory

  target=$1
  [ -e "${target%/}" ] || target=${1%"${1##*[!/]}"} # trim trailing slashes
  [ -d "${target:-/}" ] && target="$target/"

  cd -P . 2>/dev/null || return 1
  while [ "$max_symlinks" -ge 0 ] && max_symlinks=$((max_symlinks - 1)); do
    if [ ! "$target" = "${target%/*}" ]; then
      case $target in
        /*) cd -P "${target%/*}/" 2>/dev/null || break ;;
        *) cd -P "./${target%/*}" 2>/dev/null || break ;;
      esac
      target=${target##*/}
    fi

    if [ ! -L "$target" ]; then
      target="${PWD%/}${target:+/}${target}"
      printf '%s\n' "${target:-/}"
      return 0
    fi

    # `ls -dl` format: "%s %u %s %s %u %s %s -> %s\n",
    #   <file mode>, <number of links>, <owner name>, <group name>,
    #   <size>, <date and time>, <pathname of link>, <contents of link>
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/ls.html
    link=$(ls -dl -- "$target" 2>/dev/null) || break
    target=${link#*" $target -> "}
  done
  return 1
}

FQPATH=$(readlinkf_posix "$0")
ROOT=`dirname "$FQPATH"`

if [ ! -f "$ROOT/xmlcalabash-app-3.0.30.jar" ]; then
    echo "XML Calabash script did not find the 3.0.30 distribution jar"
    exit 1
fi

jarsArray=()
if [ -d "$ROOT/extra" ]; then
    for jar in "$ROOT/extra"/*.jar; do
        jarsArray+=( "$jar" )
    done
fi

for jar in "$ROOT/lib"/*.jar; do
    jarsArray+=( "$jar" )
done

CP="$ROOT/xmlcalabash-app-3.0.30.jar"
for ((idx = 0; idx < ${#jarsArray[@]}; idx++)); do
    CP="$CP:${jarsArray[$idx]}"
done

argsArray=()
propsArray=()
for arg in "$@"; do
    case $arg in
        -D*)
            propsArray+=( $arg )
            ;;
        *)
            argsArray+=( $arg )
            ;;
    esac
done

if [ -z "$JAVA_HOME" ]; then
    # I hope java is on the PATH
    java "${propsArray[@]}" -cp "$CP" com.xmlcalabash.app.Main "${argsArray[@]}"
else
    "$JAVA_HOME/bin/java" "${propsArray[@]}" -cp "$CP" com.xmlcalabash.app.Main "${argsArray[@]}"
fi

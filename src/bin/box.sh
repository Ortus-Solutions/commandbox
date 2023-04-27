#!/bin/sh

##############################################################################
##                                                                          ##
##  CommandBox JVM Bootstrap for UN*X                                       ##
##                                                                          ##
##############################################################################

cmd=
for a in "$@"
do
	case "$a" in
	-*) continue ;;
	*)  cmd=$a; break; ;;
	esac
done

# Get the location of the running script
this_script=`which "$0"`

# Prepare Java arguments
java_args="$BOX_JAVA_ARGS -client"

##############################################################################
##  OS SPECIFIC CLEANUP + ARGS
##############################################################################

# Cleanup paths for Cygwin.
case "`uname`" in
Darwin)
	if [ -e /System/Library/Frameworks/JavaVM.framework ]
	then
		java_args="
 			$BOX_JAVA_ARGS
			-client
			-Dcom.apple.mrj.application.apple.menu.about.name=CommandBox
			-Dcom.apple.mrj.application.growbox.intrudes=false
			-Dapple.laf.useScreenMenuBar=true
			-Xdock:name=CommandBox
			-Dfile.encoding=UTF-8
			-Djava.awt.headless=true
		"
	fi
	;;
esac

##############################################################################
##  JAVA DETERMINATION					                                    ##
##############################################################################

# The Embedded JRE takes precedence over a JAVA_HOME environment variable.

# Default the Java command to be global java call
java=java
# Check if JAVA_HOME is set, then use it
if [ -n "$JAVA_HOME" ]
then
	java="$JAVA_HOME/bin/java"
fi

# Verify if we have an embedded version, if we do use that instead.
JRE=$(dirname $this_script)/jre
if [ -d "$JRE" ]
then
	java="$JRE/bin/java"
fi

##############################################################################
##  EXECUTION
##############################################################################

exec "$java" $java_args -jar $this_script "$@"
exit

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

use_pager=
case "$cmd" in
blame)    use_pager=1 ;;
diff)     use_pager=1 ;;
log)      use_pager=1 ;;
esac

this_script=`which "$0" 2>/dev/null`
[ $? -gt 0 -a -f "$0" ] && this_script="$0"
cp=$this_script
#updated location to use embedded JRE
JRE=$(dirname $this_script)/bin
if [ -n "$BOX_CLASSPATH" ]
then
	cp="$cp:$BOX_CLASSPATH"
fi

java_args='-client -Djava.awt.headless=true'

# Cleanup paths for Cygwin.
#
case "`uname`" in
CYGWIN*)
	cp=`cygpath --windows --mixed --path "$cp"`
	;;
Darwin)
	if [ -e /System/Library/Frameworks/JavaVM.framework ]
	then
		java_args='
			-client
			-Dcom.apple.mrj.application.apple.menu.about.name=CommandBox
			-Dcom.apple.mrj.application.growbox.intrudes=false
			-Dapple.laf.useScreenMenuBar=true
			-Xdock:name=CommandBox
			-Dfile.encoding=UTF-8
			-Djava.awt.headless=true
		'
	fi
	;;
esac

CLASSPATH="$cp"
export CLASSPATH

java=java
if [ -n "$JAVA_HOME" ]
then
	java="$JAVA_HOME/bin/java"
fi

if [ -d "$JRE" ]
then
	java="$JRE/bin/java"
fi

if [ -n "$use_pager" ]
then
	use_pager=${BOX_PAGER:-${PAGER:-less}}
	[ cat = "$use_pager" ] && use_pager=
fi

if [ -n "$use_pager" ]
then
	LESS=${LESS:-FSRX}
	export LESS

	"$java" $java_args cliloader.LoaderCLIMain "$@" | $use_pager
	exit
else
  	exec "$java" $java_args cliloader.LoaderCLIMain "$@"
  	exit 1
fi

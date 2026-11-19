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

# Get the location of the running script without relying on `which` or `dirname`
SCRIPT_PATH="$0"
case "$SCRIPT_PATH" in
	/*) ;;
	*/*) SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
	*) SCRIPT_PATH="$(command -v -- "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")" ;;
esac
this_script=$SCRIPT_PATH

# Prepare Java arguments
##############################################################################
##  LAUNCHER CONFIG: FILES AND ENVIRONMENT VARIABLES
##############################################################################

# Same convention as the BoxLang launchers, least specific first:
#   files: boxlang.{options,properties} in the BoxLang home, then <launcher>.{options,properties}
#   env:   BOXLANG_OPTS / BOXLANG_PROPS, then <LAUNCHER>_OPTS / <LAUNCHER>_PROPS
# Later entries win, because the JVM uses the last occurrence of a repeated option.
launcher_args=

launcher_name="${this_script##*/}"
launcher_stem="${launcher_name%.*}"
launcher_dir="${this_script%/*}"
[ "$launcher_dir" = "$this_script" ] && launcher_dir=.
env_name=$( printf '%s' "$launcher_stem" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_\n' '_' )
boxlang_home="${BOXLANG_HOME:-$HOME/.boxlang}"

# Raw JVM arguments, one per line, # for comments
add_options_file() {
	[ -f "$1.options" ] || return 0
	while IFS= read -r launcher_line || [ -n "$launcher_line" ]; do
		case "$launcher_line" in
			''|'#'*) continue ;;
		esac
		launcher_args="$launcher_args $launcher_line"
	done < "$1.options"
}

# System properties, one key=value per line, # for comments
add_properties_file() {
	[ -f "$1.properties" ] || return 0
	while IFS='=' read -r launcher_key launcher_value || [ -n "$launcher_key" ]; do
		case "$launcher_key" in
			''|'#'*) continue ;;
		esac
		[ -z "$launcher_value" ] && continue
		launcher_args="$launcher_args -D$launcher_key=$launcher_value"
	done < "$1.properties"
}

# Semicolon delimited key=value pairs, the same format the property variables use
add_props_var() {
	[ -n "$1" ] || return 0
	props_left="$1;"
	while [ -n "$props_left" ]; do
		props_piece="${props_left%%;*}"
		props_left="${props_left#*;}"
		[ -n "$props_piece" ] || continue
		props_key="${props_piece%%=*}"
		[ "$props_key" = "$props_piece" ] && continue
		props_value="${props_piece#*=}"
		[ -n "$props_key" ] && launcher_args="$launcher_args -D$props_key=$props_value"
	done
}

add_options_file "$boxlang_home/boxlang"
add_properties_file "$boxlang_home/boxlang"
add_options_file "$launcher_dir/$launcher_stem"
add_properties_file "$launcher_dir/$launcher_stem"

# Legacy alias, superseded by BOX_OPTS
[ -n "${BOX_JAVA_ARGS:-}" ] && launcher_args="$launcher_args $BOX_JAVA_ARGS"

# General BoxLang layer
[ -n "${BOXLANG_OPTS:-}" ] && launcher_args="$launcher_args $BOXLANG_OPTS"
add_props_var "${BOXLANG_PROPS:-}"

# Process layer, named after the launcher that was invoked
if [ "$env_name" != "BOXLANG" ]; then
	eval "specific_opts=\${${env_name}_OPTS:-}"
	eval "specific_props=\${${env_name}_PROPS:-}"
	[ -n "$specific_opts" ] && launcher_args="$launcher_args $specific_opts"
	add_props_var "$specific_props"
fi

java_args="$launcher_args -client"

##############################################################################
##  OS SPECIFIC CLEANUP + ARGS
##############################################################################

# Cleanup paths for Cygwin.
case "`uname`" in
Darwin)
	if [ -e /System/Library/Frameworks/JavaVM.framework ]
	then
		java_args="
			$launcher_args
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
JRE="${this_script%/*}/jre"
if [ -d "$JRE" ]
then
	java="$JRE/bin/java"
fi

##############################################################################
##  EXECUTION
##############################################################################

exec "$java" $java_args -jar $this_script "$@"
exit

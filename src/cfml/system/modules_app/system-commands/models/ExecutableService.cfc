/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* I create native OS executable files that are aliases to scripts.
*/
component singleton accessors="true" {
	property name="binDirectory";
	property name='fileSystemUtil'		inject='FileSystem';
	property name='systemSettings'		inject='SystemSettings';

	/**
	 * Constructor
	 **/
	function init() {
		setBinDirectory( server.boxlang.runtimeHome & "/bin" );
		if( !directoryExists( binDirectory ) ) {
			directoryCreate( binDirectory, true );
		}
		return this;
	}

	/**
	 * @alias The name of the executable to create
	 * @command The command that the executable will run
	 **/
	function createAlias(
		required string alias,
		required string command
		) {
			var scriptLocation = binDirectory & "/" & trim( alias ) & getOSSpecificScriptExtension();
			fileWrite( scriptLocation, getScriptContent( command ) );

			// Make executable on non-Windows systems
			if ( !fileSystemUtil.isWindows() ) {
				fileSetAccessMode( scriptLocation, 755 );
			}

			return scriptLocation;
	}

	/**
	 * Create an executable that runs a BoxLang module, like `boxlang module:cli`.
	 *
	 * The boxlang binary is expanded to a full path based on the running process, so the
	 * generated executable keeps working when boxlang is not on the caller's PATH. This
	 * mirrors the launchers the BoxLang quick installers create from a module's
	 * boxlang.executable setting.
	 *
	 * @alias The name of the executable to create
	 * @moduleName The BoxLang module the executable runs
	 **/
	function createModuleAlias(
		required string alias,
		required string moduleName
		) {
			return createAlias( alias, '"' & getBoxLangBinary() & '" module:' & trim( moduleName ) );
	}

	/**
	 * Create an executable from a module-provided script body.
	 *
	 * The content is written verbatim, without path capture or any other wrapping, which
	 * mirrors how the BoxLang quick installers handle a module's boxlang.executables
	 * setting. The module owns the contents of the script.
	 *
	 * On Windows a shell script also gets a .bat wrapper that hands off to bash, the same
	 * way the BoxLang quick installers make a shipped script runnable from cmd.exe.
	 *
	 * @alias The name of the executable to create
	 * @scriptContent The complete script body to write
	 **/
	function createRawAlias(
		required string alias,
		required string scriptContent
		) {
			var baseName       = trim( alias );
			var scriptLocation = binDirectory & "/" & baseName;
			fileWrite( scriptLocation, arguments.scriptContent );

			// Make executable on non-Windows systems
			if ( !fileSystemUtil.isWindows() ) {
				fileSetAccessMode( scriptLocation, 755 );
			} else if ( arguments.scriptContent.ltrim().startsWith( '##!/' ) ) {
				// The module shipped a shell script, so cmd.exe needs a way in
				fileWrite(
					binDirectory & "/" & baseName & ".bat",
					'@echo off' & chr( 13 ) & chr( 10 ) & 'bash "%~dp0' & baseName & '" %*'
				);
			}

			return scriptLocation;
	}

	/**
	 * Remove an executable created by createRawAlias.
	 *
	 * A module script can exist both as the raw script and as its Windows bash wrapper,
	 * so both are removed when either is present.
	 *
	 * @alias The name of the executable to remove
	 * @return True if anything was removed
	 **/
	function removeRawAlias( required string alias ) {
		var baseName = trim( alias );
		var removed  = false;

		for( var location in [ binDirectory & "/" & baseName, binDirectory & "/" & baseName & ".bat" ] ) {
			if( fileExists( location ) ) {
				fileDelete( location );
				removed = true;
			}
		}

		return removed;
	}

	/**
	 * Get the full path to the "box" binary that started the current process.
	 *
	 * CommandBox 7 and higher record the launcher in BOX_PROCESS_PATH. Older versions and
	 * unusual launch styles fall back to whatever "box" resolves to on the PATH.
	 **/
	string function getBoxBinary() {
		var processPath = systemSettings.getEnv( 'BOX_PROCESS_PATH', '' );
		if( isSimpleValue( processPath ) && len( trim( processPath ) ) ) {
			return trim( processPath );
		}

		var onPath = findOnPath( 'box' );
		return len( onPath ) ? onPath : 'box';
	}

	/**
	 * Get the full path to the "boxlang" binary.
	 *
	 * Resolution order matches the BoxLang quick installers: an explicit BOXLANG_BINARY
	 * override, then a boxlang launcher sitting next to the resolved box binary, then the
	 * PATH. When nothing is found, a bare "boxlang" is returned so the executable still
	 * works for callers that do have it on their PATH.
	 **/
	string function getBoxLangBinary() {
		var override = systemSettings.getEnv( 'BOXLANG_BINARY', '' );
		if( isSimpleValue( override ) && len( trim( override ) ) ) {
			return trim( override );
		}

		// The box launcher usually lives beside the boxlang launcher
		var boxDirectory = getDirectoryFromPath( getBoxBinary() );
		if( len( boxDirectory ) ) {
			for( var name in getBinaryNames( 'boxlang' ) ) {
				var sibling = boxDirectory & name;
				if( fileExists( sibling ) ) {
					return sibling;
				}
			}
		}

		var onPath = findOnPath( 'boxlang' );
		return len( onPath ) ? onPath : 'boxlang';
	}

	/**
	 * Get the OS specific file names a binary is usually installed as.
	 *
	 * @binary The binary name without an extension
	 **/
	private array function getBinaryNames( required string binary ) {
		if ( fileSystemUtil.isWindows() ) {
			return [ arguments.binary & '.bat', arguments.binary & '.exe', arguments.binary ];
		}
		// Unix executables typically have no extension
		return [ arguments.binary ];
	}

	/**
	 * Look a binary up on the PATH without shelling out.
	 *
	 * @binary The binary name without an extension
	 * @return The absolute path, or an empty string when it is not on the PATH
	 **/
	private string function findOnPath( required string binary ) {
		var pathSeparator = fileSystemUtil.isWindows() ? ';' : ':';
		var names = getBinaryNames( arguments.binary );

		for( var directory in listToArray( systemSettings.getEnv( 'PATH', '' ), pathSeparator ) ) {
			if( !len( trim( directory ) ) ) {
				continue;
			}
			for( var name in names ) {
				var candidate = trim( directory ) & "/" & name;
				if( fileExists( candidate ) ) {
					return candidate;
				}
			}
		}

		return '';
	}

	/**
	 * Get the OS specific script extension.
	 **/
	private function getOSSpecificScriptExtension() {
		if ( fileSystemUtil.isWindows() ) {
			return ".bat";
		} else {
			// Unix executables typically have no extension
			return "";
		}
	}

	/**
	 * Get the script content for the OS.
	 *
	 * @command The command that the script will execute
	 **/
	private function getScriptContent( required string command ) {
		if ( fileSystemUtil.isWindows() ) {
			// @ suppresses echo, %* passes all arguments
			return '@if not defined BOX_PROCESS_PATH set "BOX_PROCESS_PATH=%~f0"' & chr( 13 ) & chr( 10 ) &
				"@" & command & " %*";
		} else {
			// Unix shell script (Mac and Linux)
			// #!/bin/sh - POSIX shell for maximum portability (works on bash, zsh, dash, etc.)
			// exec - Replaces shell process with command (cleaner signal handling, no "shell" parent)
			// "$@" - Passes all arguments to the command (properly quoted)
			// POSIX-only builtins and expansions so this runs on dash, ash/busybox (Alpine), etc.
			return "##!/bin/sh" & chr( 10 ) &
				'if [ -z "${BOX_PROCESS_PATH:-}" ]; then' & chr( 10 ) &
				'	BOX_PROCESS_PATH="$0"' & chr( 10 ) &
				'	case "$BOX_PROCESS_PATH" in' & chr( 10 ) &
				"		*/*) ;;" & chr( 10 ) &
				'		*) BOX_PROCESS_PATH="$(command -v -- "$BOX_PROCESS_PATH" 2>/dev/null || printf %s "$BOX_PROCESS_PATH")" ;;' & chr( 10 ) &
				"	esac" & chr( 10 ) &
				'	case "$BOX_PROCESS_PATH" in' & chr( 10 ) &
				'		*/*) BOX_PROCESS_PATH="$(CDPATH= cd -P "${BOX_PROCESS_PATH%/*}" && pwd -P)/${BOX_PROCESS_PATH####*/}" ;;' & chr( 10 ) &
				"	esac" & chr( 10 ) &
				"fi" & chr( 10 ) &
				"export BOX_PROCESS_PATH" & chr( 10 ) &
				"exec " & command & ' "$@"';
		}
	}

	/**
	 * List all executable aliases in the bin directory.
	 *
	 * @return An array of structs containing alias information
	 **/
	function listAliases() {
		var aliases = [];
		var extension = getOSSpecificScriptExtension();

		if ( !directoryExists( binDirectory ) ) {
			return aliases;
		}

		directoryList( binDirectory, false, "query", "*#extension#" ).each( function( file ) {
			var aliasName = file.name.replaceNoCase( extension, "" );
			var scriptContent = fileRead( binDirectory & "/" & file.name );
			var command = parseCommandFromScript( scriptContent );
			aliases.append( {
				"alias"    : aliasName,
				"command"  : command,
				"location" : binDirectory & "/" & file.name
			} );
		} );

		return aliases;
	}

	/**
	 * Get information about a specific alias.
	 *
	 * @alias The name of the alias to retrieve
	 * @return A struct containing alias information, or an empty struct if not found
	 **/
	function getAlias( required string alias ) {
		var scriptLocation = binDirectory & "/" & trim( alias ) & getOSSpecificScriptExtension();

		if ( !fileExists( scriptLocation ) ) {
			return {};
		}

		var scriptContent = fileRead( scriptLocation );
		return {
			"alias"    : trim( alias ),
			"command"  : parseCommandFromScript( scriptContent ),
			"location" : scriptLocation
		};
	}

	/**
	 * Remove an executable alias.
	 *
	 * @alias The name of the alias to remove
	 * @return True if the alias was removed, false if it didn't exist
	 **/
	function removeAlias( required string alias ) {
		var scriptLocation = binDirectory & "/" & trim( alias ) & getOSSpecificScriptExtension();

		if ( !fileExists( scriptLocation ) ) {
			return false;
		}

		fileDelete( scriptLocation );
		return true;
	}

	/**
	 * Parse the command from script content.
	 *
	 * @scriptContent The content of the script file
	 * @return The command extracted from the script
	 **/
	private function parseCommandFromScript( required string scriptContent ) {
		var lines = scriptContent.trim().listToArray( chr( 10 ) );
		if ( lines.len() ) {
			// Both formats end with the command, including aliases created before path capture was added.
			var commandLine = lines[ lines.len() ].trim();
			if ( fileSystemUtil.isWindows() ) {
				return commandLine
					.reReplaceNoCase( "^@", "" )
					.reReplaceNoCase( "\s*%\*$", "" );
			} else if ( lines.len() >= 2 ) {
				return commandLine
					.reReplaceNoCase( "^exec\s+", "" )
					.reReplaceNoCase( '\s*"\$@"$', "" );
			}
		}
		return "";
	}

}
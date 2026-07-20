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
			// Windows batch file - simple single line
			// @ suppresses echo, %* passes all arguments
			return "@" & command & " %*";
		} else {
			// Unix shell script (Mac and Linux)
			// #!/bin/sh - POSIX shell for maximum portability (works on bash, zsh, dash, etc.)
			// exec - Replaces shell process with command (cleaner signal handling, no "shell" parent)
			// "$@" - Passes all arguments to the command (properly quoted)
			return "##!/bin/sh" & chr( 10 ) &
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
		if ( fileSystemUtil.isWindows() ) {
			// Windows: single line format "@command %*"
			return scriptContent.trim()
				.reReplaceNoCase( "^@", "" )
				.reReplaceNoCase( "\s*%\*$", "" );
		} else {
			// Unix: extract command from second line, remove "exec " prefix and trailing "$@"
			var lines = scriptContent.listToArray( chr( 10 ) );
			if ( lines.len() >= 2 ) {
				return lines[ 2 ].trim()
					.reReplaceNoCase( "^exec\s+", "" )
					.reReplaceNoCase( '\s*"\$@"$', "" );
			}
		}
		return "";
	}

}
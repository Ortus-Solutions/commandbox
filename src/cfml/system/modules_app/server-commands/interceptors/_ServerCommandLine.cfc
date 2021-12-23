/**
 *********************************************************************************
 * Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 * www.coldbox.org | www.ortussolutions.com
 ********************************************************************************
 *
 * I am an interceptor that listens for the server start command line arguments
 * and generates a shell script from them if `startScript` is specified.
 *
 */
component {

	property name="job"            inject="interactiveJob";
	property name="fileSystemUtil" inject="fileSystem";
	property name="CR"             inject="CR@constants";
	property name="systemSettings" inject="SystemSettings";
	property name="print"          inject="PrintBuffer";

	variables.shellScripts = {
		bash: { ext: 'sh', startlines: [ '##!/bin/bash', '' ], endlines: [] },
		cmd : { ext: 'bat', startlines: [ '@echo off', 'setlocal' ], endlines: [ 'endlocal' ] },
		pwsh: { ext: 'ps1', startlines: [], endlines: [] }
	};

	function onServerProcessLaunch( struct interceptData ) {
		if( interceptData.serverProps.keyExists( 'startScript' ) && len( interceptData.serverProps.startScript ) ) {
			if( !shellScripts.keyExists( interceptData.serverProps.startScript ) ) {
				job.addErrorLog(
					'Invalid target shell specified [#interceptData.serverProps.startScript#] for command line shell script. Unable to generate script.'
				);
			} else {
				generateStartScript(
					interceptData.commandLineArguments,
					interceptData.serverProps.startScript,
					interceptData.serverProps.startScriptFile ?: '',
					interceptData.serverInfo.serverConfigFile
				);
			}
		}
	}

	private function generateStartScript(
		required array commandLineArguments,
		required string targetShell,
		required string startScriptFile,
		required string serverConfigFile
	) {
		if( !startScriptFile.len() ) {
			startScriptFile = getFileFromPath( serverConfigFile );
			if( startScriptFile.startsWith( 'server' ) ) {
				startScriptFile = startScriptFile.replace( 'server', 'server-start' );
			} else {
				startScriptFile = 'server-start-' & startScriptFile;
			}
			startScriptFile = startScriptFile.left( -4 ) & shellScripts[ targetShell ].ext;
			startScriptFile = getDirectoryFromPath( serverConfigFile ) & startScriptFile;
		}

		startScriptFile = fileSystemUtil.resolvePath( startScriptFile );

		var cmdLines = [];
		cmdLines.append( shellScripts[ targetShell ].startlines, true );
		cmdLines.append( encodeShellEnv( targetShell ), true );
		cmdLines.append( encodeShellCmd( commandLineArguments, targetShell ) );
		cmdLines.append( shellScripts[ targetShell ].endlines, true );
		fileWrite( startScriptFile, cmdLines.toList( cr ) & cr );

		job.addLog( 'Start script for shell [#targetShell#] generated at: #startScriptFile#' );
	}

	private function encodeShellEnv( required string targetShell ) {
		var cmdEnv = systemSettings.getAllEnvironmentsFlattened();

		var shellEncoders = {
			bash: function( result, key, value ) {
				// in bash, only a-z, A-Z, _ and 0-9 are allowed for env variables
				// so java props with `.` in the key are out
				if( reFind( '^[a-zA-Z_]+[a-zA-Z0-9_]*$', key ) ) {
					result.append( "export #key#='#value.replace( "'", "'\''", "all" )#'" );
				}
				return result;
			},
			cmd: function( result, key, value ) {
				var escapedvalue = '';
				var inQuotes = false;
				for( var char in toString( value ).listToArray( '' ) ) {
					if( char == '"' ) {
						inQuotes = !inQuotes;
					}
					// Escape special chars <>|& but only if not currently inside quotes
					if( inQuotes ) {
						escapedvalue &= char;
					} else {
						escapedvalue &= char.reReplace( '([<>\|\&\^])', '^\1', 'all' );
					}
				}
				result.append( 'set #key#=#escapedvalue.replace( "%", "%%", "all" )#' );
				return result;
			},
			pwsh: function( result, key, value ) {
				key = "${env:#key.reReplace( '([{}])', '`\1', 'all' )#}";
				value = "'" & value.replace( "'", "''", "all" ) & "'";
				result.append( '#key#=#value#' );
				return result;
			}
		};

		return cmdEnv.reduce( shellEncoders[ targetShell ], [] );
	}

	private function encodeShellCmd( required array args, required string targetShell ) {
		var shellNewlineEscape = { bash: '\', cmd: '^', pwsh: '`' };
		var newLineSep         = ' ' & shellNewlineEscape[ targetShell ] & cr & chr( 9 );
		var reducer            = ( r, a ) => r & ( a.reFind( '^[''"]?-' ) ? newLineSep : ' ' ) & a;
		return args
			.map( escapeCommandArgs( targetShell ) )
			.reduce( reducer, '' )
			.ltrim();
	}

	private function escapeCommandArgs( required string targetShell ) {
		var shellEscapes = {
			bash: function( arg, idx ) {
				if( idx == 1 ) {
					// actual process to run, don't quote this
					// add exec so that the java process replaces the shell process
					return 'exec ' & toString( arg ).replace( ' ', '\ ', 'all' );
				}
				// otherwise, just fully quote with _single_ quotes
				return "'" & toString( arg ).replace( "'", "'\''", "all" ) & "'";
			},
			cmd: function( arg, idx ) {
				var segment = toString( arg );
				// Wrap this arg up in quotes and double up any quotes already inside of it
				segment = '"#segment.replace( '"', '""', 'all' )#"';
				// Also any literal values of \" need to be turned into \\"
				segment = segment.replace( '\"', '\\"', 'all' );
				// Any % chars need to be turned into %%
				segment = segment.replace( '%', '%%', 'all' );
				return segment;
			},
			pwsh: function( arg, idx ) {
				var specialChars = '([{}()@|!''"; &`$##])';
				if( idx == 1 ) {
					// actual process to run, don't quote this
					return toString( arg ).reReplace(specialChars, '`\1', 'all');
				}
				// otherwise, just fully quote with single quotes
				arg = "'" & toString( arg ).replace( "'", "''", "all" ) & "'";
				// Also any literal values of " need to be escaped for the underlying Java
				// process that is called. If the " was preceded by a \ then that needs
				// to be escaped as well
				return arg.replace( '"', '\"', 'all' ).replace( '\\"', '\\\"', 'all' );
			}
		};

		return shellEscapes[ targetShell ];
	}

}

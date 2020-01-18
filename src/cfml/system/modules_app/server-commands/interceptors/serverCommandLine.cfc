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
		if( interceptData.serverProps.keyExists( 'startScript' ) ) {
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
			bash:function( result, key, value ) {
				result.append( 'export #key#="#value.replace( '"', '\"', 'all' )#"' );
				return result;
			},
			cmd:function( result, key, value ) {
				result.append( 'set #key#=#value#' );
				return result;
			},
			pwsh:function( result, key, value ) {
				result.append( '$env:#key#="#value.replace( '"', '`"', 'all' )#"' );
				return result;
			}
		};

		return cmdEnv.reduce( shellEncoders[ targetShell ], [] );
	}

	private function encodeShellCmd( required array args, required string targetShell ) {
		var shellNewlineEscape = { bash: '\', cmd: '^', pwsh: '`' };
		var newLineSep         = ' ' & shellNewlineEscape[ targetShell ] & cr & chr( 9 );
		var reducer            = ( r, a ) => r & ( a.startswith( '-' ) ? newLineSep : ' ' ) & a;
		return args
			.map( escapeCommandArgs( targetShell ) )
			.reduce( reducer, '' )
			.ltrim();
	}

	private function escapeCommandArgs( required string targetShell ) {
		// regex to split a string into quoted and unquoted segments
		var segmentRegex = function( escapeChar ) {
			if( !isNull( arguments.escapeChar ) ) {
				// (?:[^"]|#escapeChar#.)+
				// match anything that is not a quote or is an escape followed by anything
				// or
				// "(?:[^"]|#escapeChar#.)*"
				// match an opening quote, followed by matching anything that is not
				// a quote or is an escape followed by anything, followed by a closing quote
				return '(?:[^"]|#escapeChar#.)+|"(?:[^"]|#escapeChar#.)*"';
			}
			// if no escape char, then just match unquoted and quoted sections
			return '[^"]+|"[^"]*"';
		};

		var shellEscapes = {
			bash:function( arg, idx ) {
				return toString( arg )
					.reMatch( segmentRegex( '\\' ) )
					.map( ( segment ) => {
						if( !segment.startswith( '"' ) ) {
							segment = segment.replace( ' ', '\ ', 'all' );
						}
						return segment;
					} )
					.toList( '' );
			},
			cmd:function( arg, idx ) {
				return toString( arg )
					.reMatch( segmentRegex() )
					.map( ( segment ) => {
						if( !segment.startswith( '"' ) and segment.find( ' ' ) ) {
							segment = '"#segment#"';
						}
						if( segment.endswith( '\"' ) ) {
							// cmd will pass this literally, so we need to escape it for the underlying Java process
							segment = segment.left( -2 ) & '\\"';
						}
						return segment;
					} )
					.toList( '' );
			},
			pwsh:function( arg, idx ) {
				return toString( arg )
					.reMatch( segmentRegex( '`' ) )
					.map( ( segment ) => {
						if( !segment.startswith( '"' ) ) {
							segment = segment.replace( ' ', '` ', 'all' );
						}
						// PowerShell needs the `-` in single `-` args escaped when they contain periods
						// or it will split the argument at the period
						if( segment.reFind( '^-(?!-)' ) && segment.find( '.' ) ) {
							segment = '`' & segment;
						}
						return segment;
					} )
					.toList( '' );
			}
		};

		return shellEscapes[ targetShell ];
	}

}

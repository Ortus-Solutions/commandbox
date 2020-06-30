/**
 * Show log for embedded server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server log
 * server log name=serverName
 * {code}
 **/
component {

	property name="serverService"	inject="ServerService";
	property name="printUtil"		inject="print";

	/**
	 * Show server log
	 *
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 * @follow Tail the log file with the "follow" flag. Press Ctrl-C to quit.
	 * @access View/tail the access log
	 * @rewrites View/tail the rewrites log
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		Boolean follow=false,
		Boolean access=false,
		Boolean rewrites=false
		 ){
		if( !isNull( arguments.directory ) ) {
			arguments.directory = resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
		}
		var serverDetails = serverService.resolveServerDetails( arguments );
		var serverInfo = serverDetails.serverInfo;

		// Verify server info
		if( serverDetails.serverIsNew ){
			error( "The server you requested was not found.", "You can use the 'server list' command to get all the available servers." );
		}

		var logfile = serverInfo.logdir & "/server.out.txt";
		if( access ) {
			logfile = serverInfo.accessLogPath;
		}
		if( rewrites ) {
			logfile = serverInfo.rewritesLogPath;
		}
		if( fileExists( logfile) ){

			if( follow ) {
				command( 'tail' )
					.params( logfile, 50 )
					.flags( 'follow' )
					.run();
			} else {
				return fileRead( logfile )
					.listToArray( chr( 13 ) & chr( 10 ) )
					.map( function( line ) {
						return cleanLine( line );
					} )
					.toList( chr( 10 ) );
			}

		} else {
			print.boldRedLine( "No log file found for '#serverInfo.webroot#'!" )
				.line( "#logFile#" );
			if( access ) {
				print.yellowLine( 'Enable accesss logging with [server set web.accessLogEnable=true]' );
			}
			if( rewrites ) {
				print.yellowLine( 'Enable Rewrite logging with [server set web.rewrites.logEnable=true] and ensure you are started in debug mode.' );
			}
		}
	}
	
	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}

	private function cleanLine( line ) {
		
		// Log messages from the CF engine or app code writing direclty to std/err out strip off "runwar.context" but leave color coded severity
		// Ex:
		// [INFO ] runwar.context: 04/11 15:47:10 INFO Starting Flex 1.5 CF Edition
		line = reReplaceNoCase( line, '^(\[[^]]*])( runwar\.context: )(.*)', '\1 \3' );
		
		// Log messages from runwar itself, simplify the logging category to just "Runwar:" and leave color coded severity
		// Ex:
		// [DEBUG] runwar.config: Enabling Proxy Peer Address handling
		// [DEBUG] runwar.server: Starting open browser action
		line = reReplaceNoCase( line, '^(\[[^]]*])( runwar\.[^:]*: )(.*)', '\1 Runwar: \3' );
		
		// Strip off redundant severities that come from wrapping LogBox apenders in Log4j appenders
		// [INFO ] DEBUG my.logger.name This rain in spain stays mainly in the plains
		line = reReplaceNoCase( line, '^(\[(INFO |ERROR|DEBUG|WARN )] )(INFO|ERROR|DEBUG|WARN)( .*)', '[\3]\4' );
		
		// Add extra space so [WARN] becomes [WARN ]
		line = reReplaceNoCase( line, '^\[(INFO|WARN)]( .*)', '[\1 ]\2' );
				
		if( line.startsWith( '[INFO ]' ) ) {
			return reReplaceNoCase( line, '^(\[INFO ] )(.*)', '[#printUtil.boldCyan('INFO ')#] \2' );
		}

		if( line.startsWith( '[ERROR]' ) ) {
			return reReplaceNoCase( line, '^(\[ERROR] )(.*)', '[#printUtil.boldMaroon('ERROR')#] \2' );
		}

		if( line.startsWith( '[DEBUG]' ) ) {
			return reReplaceNoCase( line, '^(\[DEBUG] )(.*)', '[#printUtil.boldOlive('DEBUG')#] \2' );
		}

		if( line.startsWith( '[WARN ]' ) ) {
			return reReplaceNoCase( line, '^(\[WARN ] )(.*)', '[#printUtil.boldYellow('WARN ')#] \2' );
		}

		return line;

	}

}

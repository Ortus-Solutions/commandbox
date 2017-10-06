/**
 * Show brief details of all embedded servers that have been run.  Use this command to get a quick report on the servers you
 * are using or have used.  To get more detailed status on a server, use the "server status" command.
 * .
 * {code:bash}
 * server list
 * {code}
 * .
 * Show additional server information with the verbose flag
 * .
 * {code:bash}
 * server list --verbose
 * {code}
 * .
 * You can filter the servers that show by status
 * .
 * {code:bash}
 * server list --running
 * server list --stopped
 * server list --starting
 * server list --unknown
 * {code}
 * .
 * You can also supply a comma-delimited list of server short names to display
 * .
 * {code:bash}
 * server list myApp,contentbox,testSite
 * {code}
 * .
 * If you provide a single name, it will be treated as a partial match and return server names that contain that phrase
 * .
 * {code:bash}
 * # Returns servers named "client1" and "client2"
 * server list client
 * {code}
 **/
component {

	// DI
	property name="serverService" inject="ServerService";

	/**
	 * @name.hint Comma-delimited list of server names to show
	 * @name.optionsUDF serverNameComplete
	 * @running.hint Show running servers
	 * @stopped.hint Show stopped servers
	 * @starting.hint Show starting servers
	 * @unknown.hint Show servers with unknown status
	 * @verbose.hint Show detailed information
	 **/
	function run(
		name='',
		boolean running = false,
		boolean stopped = false,
		boolean starting = false,
		boolean unknown = false,
		boolean verbose = false ){
		var servers = serverService.getServers();

		var statusList = '';
		if( arguments.running ) { statusList = statusList.listAppend( 'running' ); }
		if( arguments.stopped ) { statusList = statusList.listAppend( 'stopped' ); }
		if( arguments.starting ) { statusList = statusList.listAppend( 'starting' ); }
		if( arguments.unknown ) { statusList = statusList.listAppend( 'unknown' ); }

		// Map the server statuses to a color
		statusColors = {
			running : 'green',
			starting : 'yellow',
			stopped : 'red'
		};

		for( var thisKey in servers ){
			var thisServerInfo = servers[ thisKey ];
			var status = serverService.isServerRunning( thisServerInfo ) ? 'running' : 'stopped';

			// Check name and status filters.  By default, everything shows
			if( ( !len( arguments.name ) || matchesName( thisServerInfo.name, arguments.name ) )
				&& ( !len( statusList ) || listFindNoCase( statusList, status ) ) ) {

				// Null Checks, to guarnatee correct struct.
				structAppend( thisServerInfo, serverService.newServerInfoStruct(), false );

				print.line().boldText( thisServerInfo.name );
				print.boldtext( ' (' )
					.bold( status, statusColors.keyExists( status ) ? statusColors[ status ] : 'yellow' )
					.bold( ')' )
					.line();

				if( arguments.verbose ) {

					print.indentedLine( "host:             " & thisServerInfo.host );
					if( len( thisServerInfo.engineName ) ) {
						print.indentedLine( "CF Engine:        " & thisServerInfo.engineName & ' ' & thisServerInfo.engineVersion );
					}
					if( len( thisServerInfo.WARPath ) ) {
						print.indentedLine( "WARPath:          " & thisServerInfo.WARPath );
					} else {
						print.indentedLine( "webroot:          " & thisServerInfo.webroot );
					}
					if( len( thisServerInfo.dateLastStarted ) ) {
						print.indentedLine( 'Last Started: ' & datetimeFormat( thisServerInfo.dateLastStarted ) );
					}
					print.indentedLine( "HTTPEnable:       " & thisServerInfo.HTTPEnable )
						.indentedLine( "port:             " & thisServerInfo.port )
						.indentedLine( "SSLEnable:        " & thisServerInfo.SSLEnable )
						.indentedLine( "SSLport:          " & thisServerInfo.SSLport )
						.indentedLine( "rewritesEnable:   " & ( thisServerInfo.rewritesEnable ?: "false" ) )
						.indentedLine( "stopsocket:       " & thisServerInfo.stopsocket )
						.indentedLine( "logdir:           " & thisServerInfo.logDir )
						.indentedLine( "debug:            " & thisServerInfo.debug )
						.indentedLine( "ID:               " & thisServerInfo.id );

					if( len( thisServerInfo.libDirs ) ) { print.indentedLine( "libDirs:          " & thisServerInfo.libDirs ); }
					if( len( thisServerInfo.webConfigDir ) ) { print.indentedLine( "webConfigDir:     " & thisServerInfo.webConfigDir ); }
					if( len( thisServerInfo.serverConfigDir ) ) { print.indentedLine( "serverConfigDir:  " & thisServerInfo.serverConfigDir ); }
					if( len( thisServerInfo.webXML ) ) { print.indentedLine( "webXML:           " & thisServerInfo.webXML ); }
					if( len( thisServerInfo.trayicon ) ) { print.indentedLine( "trayicon:         " & thisServerInfo.trayicon ); }
					if( len( thisServerInfo.serverConfigFile ) ) { print.indentedLine( "serverConfigFile: " & thisServerInfo.serverConfigFile ); }

				} else {
					// Brief version
					if( thisServerInfo.HTTPEnable ) {
						print.indentedLine( 'http://' & thisServerInfo.host & ':' & thisServerInfo.port );
					}
					if( thisServerInfo.SSLEnable ) {
						print.indentedLine( 'https://' & thisServerInfo.host & ':' & thisServerInfo.SSLport );
					}
					if( len( thisServerInfo.engineName ) ) {
						print.indentedLine( 'CF Engine: ' & thisServerInfo.engineName & ' ' & thisServerInfo.engineVersion );
					}
					if( len( thisServerInfo.warPath ) ) {
						print.indentedLine( 'WAR Path: ' & thisServerInfo.warPath );
					} else {
						print.indentedLine( 'Webroot: ' & thisServerInfo.webroot );
					}
					if( len( thisServerInfo.dateLastStarted ) ) {
						print.indentedLine( 'Last Started: ' & datetimeFormat( thisServerInfo.dateLastStarted ) );
					}
				}// end verbose

			} // End "filter" if
		}

		// No servers found, then do nothing
		if( structCount( servers ) eq 0 ){
			print.boldRedLine( "No server configurations found!" );
		}
	}

	function matchesName( name, searchTerm ) {
		if( listLen( searchTerm ) > 1 ) {
			return listFindNoCase( searchTerm, name );
		} else {
			return findNoCase( searchTerm, name );
		}
	}

	function serverNameComplete() {
		return serverService.getServerNames();
	}


}

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
 **/
component extends="commandbox.system.BaseCommand" aliases="status" excludeFromHelp=false {

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

			// Check name and status filters.  By default, everything shows
			if( ( !len( arguments.name ) || listFindNoCase( arguments.name, thisServerInfo.name ) )
				&& ( !len( statusList ) || listFindNoCase( statusList, thisServerInfo.status ) ) ) {
			
				// Null Checks, to guarnatee correct struct.
				structAppend( thisServerInfo, serverService.newServerInfoStruct(), false );
	
				print.line().boldText( thisServerInfo.name );
	
				var status = thisServerInfo.status;
				print.boldtext( ' (' )
					.bold( status, statusColors.keyExists( status ) ? statusColors[ status ] : 'yellow' )
					.bold( ')' )
					.line();
					
				if( arguments.verbose ) {
						
					print.indentedLine( "host:            " & thisServerInfo.host )
						.indentedLine( "enableHTTP:      " & thisServerInfo.enableHTTP )
						.indentedLine( "port:            " & thisServerInfo.port )
						.indentedLine( "enableSSL:       " & thisServerInfo.enableSSL )
						.indentedLine( "SSLport:         " & thisServerInfo.SSLport )
						.indentedLine( "Rewrites:        " & ( thisServerInfo.rewrites ?: "false" ) )
						.indentedLine( "stopsocket:      " & thisServerInfo.stopsocket )
						.indentedLine( "logdir:          " & thisServerInfo.logDir )
						.indentedLine( "debug:           " & thisServerInfo.debug )
						.indentedLine( "ID:              " & thisServerInfo.id );
						
					if( len( thisServerInfo.libDirs ) ) { print.indentedLine( "libDirs:         " & thisServerInfo.libDirs ); }
					if( len( thisServerInfo.webConfigDir ) ) { print.indentedLine( "webConfigDir:    " & thisServerInfo.webConfigDir ); }
					if( len( thisServerInfo.serverConfigDir ) ) { print.indentedLine( "serverConfigDir: " & thisServerInfo.serverConfigDir ); }
					if( len( thisServerInfo.webXML ) ) { print.indentedLine( "webXML:          " & thisServerInfo.webXML ); }
					if( len( thisServerInfo.trayicon ) ) { print.indentedLine( "trayicon:        " & thisServerInfo.trayicon ); }
						
				} else {
					// Brief version
					if( thisServerInfo.enableSSL ) {
						print.indentedLine( 'http://' & thisServerInfo.host & ':' & thisServerInfo.port );
					}
					if( thisServerInfo.enableHTTP ) {
						print.indentedLine( 'https://' & thisServerInfo.host & ':' & thisServerInfo.SSLport );
					}
					print.indentedLine( thisServerInfo.webroot );
				}// end verbose
						
			} // End "filter" if
		}

		// No servers found, then do nothing
		if( structCount( servers ) eq 0 ){
			print.boldRedLine( "No server configurations found!" );
		}
	}
	
	function serverNameComplete() {
		return serverService.getServerNames();
	}
	
 
}
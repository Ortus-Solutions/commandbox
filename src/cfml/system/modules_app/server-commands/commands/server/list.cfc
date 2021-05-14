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
 * server list --local
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

	// Map the server statuses to a color
	variables.statusColors = {
		running 	: 'green',
		starting 	: 'yellow',
		stopped 	: 'red'
	};

	/**
	 * @name Comma-delimited list of server names to show
	 * @name.optionsUDF serverNameComplete
	 * @running Show running servers
	 * @stopped Show stopped servers
	 * @starting Show starting servers
	 * @unknown Show servers with unknown status
	 * @verbose Show detailed information
	 * @local Show servers with webroot matching the current directory
	 * @JSON Return results in JSON
	 **/
	function run(
		name='',
		boolean running = false,
		boolean stopped = false,
		boolean starting = false,
		boolean unknown = false,
		boolean verbose = false,
		boolean local = false,
		boolean JSON = false
	){
		var statusList = [];
		if( arguments.running ) { statusList 	= statusList.append( 'running' ); }
		if( arguments.stopped ) { statusList 	= statusList.append( 'stopped' ); }
		if( arguments.starting ) { statusList 	= statusList.append( 'starting' ); }
		if( arguments.unknown ) { statusList 	= statusList.append( 'unknown' ); }

		// Local ref to avoid the `local` scope issue
		var localOnly = arguments.local;

		// Get Servers
		var servers = serverService.getServers();

		if( !JSON ) {
			// Verbalize yourself!
			print
				.boldCyanLine( "Processing (#servers.count()#) servers, please wait..." )
				.toConsole();	
		}

		// Re-assign to calculate at the end
		servers = servers
			// filter out what we don't need
			.filter( ( serverName, thisServerInfo ) => {
				return (
					// Name check?
					( !len( name ) || matchesName( thisServerInfo.name, name ) ) &&
					// Local or OS Wide (default)
					( !localOnly || getCanonicalPath( getCWD() ) == getCanonicalPath( thisServerInfo.webroot ) )
				);
			}, true )
			// Process status + Null Checks, to guarantee correct struct correctness, do this async
			.map( ( serverName, thisServerInfo ) => {
				thisServerInfo.append( serverService.newServerInfoStruct(), false );
				thisServerInfo.status = getServerStatus( thisServerInfo );
				return thisServerInfo;
			}, true )
			// Filter out by status now if needed now.
			.filter( ( serverName, thisServerInfo ) => {
				return ( !statusList.len() || statusList.findNoCase( thisServerInfo.status ) )
			} );
			
			
			// Process output
			if( JSON ) {
				print.line( servers.valueArray() );
			} else {
				servers.each( ( serverName, thisServerInfo ) => {
					// Print out Header
					print.line().boldText( thisServerInfo.name );
					print.boldtext( ' (' )
						.bold( thisServerInfo.status, getStatusColor( thisServerInfo.status ) )
						.bold( ')' )
						.line();
	
					// Basic or verbose
					if( verbose ) {
						printVerboseServerInfo( thisServerInfo )
					} else {
						printServerInfo( thisServerInfo );
					}
				} );
				
				// No servers found, then do nothing
				if( servers.count() eq 0 ){
					print.boldRedLine( "No server configurations found with the incoming filters!" );
				}
			}
			

	}

	/**
	 * Get the server status
	 *
	 * @serverInfo The server info struct
	 *
	 * @return The status string
	 */
	string function getServerStatus( required serverInfo ){
		return variables.serverService.isServerRunning( arguments.serverInfo ) ? 'running' : 'stopped';
	}

	/**
	 * Print basic server info to the print stream
	 *
	 * @serverInfo The server info struct
	 */
	function printServerInfo( required serverInfo ){
		// Brief version
		if( serverInfo.HTTPEnable ) {
			print.indentedLine( 'http://' & serverInfo.host & ':' & serverInfo.port );
		}
		if( serverInfo.SSLEnable ) {
			print.indentedLine( 'https://' & serverInfo.host & ':' & serverInfo.SSLport );
		}
		if( len( serverInfo.engineName ) ) {
			print.indentedLine( 'CF Engine: ' & serverInfo.engineName & ' ' & serverInfo.engineVersion );
		}
		if( len( serverInfo.warPath ) ) {
			print.indentedLine( 'WAR Path: ' & serverInfo.warPath );
		} else {
			print.indentedLine( 'Webroot: ' & serverInfo.webroot );
		}
		if( len( serverInfo.dateLastStarted ) ) {
			print.indentedLine( 'Last Started: ' & datetimeFormat( serverInfo.dateLastStarted ) );
		}
	}

	/**
	 * Print verbose server info to the print stream
	 *
	 * @serverInfo The server info struct
	 */
	function printVerboseServerInfo( required serverInfo ){
		print.indentedLine( "host:             " & serverInfo.host );
		if( len( serverInfo.engineName ) ) {
			print.indentedLine( "CF Engine:        " & serverInfo.engineName & ' ' & serverInfo.engineVersion );
		}
		if( len( serverInfo.WARPath ) ) {
			print.indentedLine( "WARPath:          " & serverInfo.WARPath );
		} else {
			print.indentedLine( "webroot:          " & serverInfo.webroot );
		}
		if( len( serverInfo.dateLastStarted ) ) {
			print.indentedLine( 'Last Started:     ' & datetimeFormat( serverInfo.dateLastStarted ) );
		}
		print.indentedLine( "HTTPEnable:       " & serverInfo.HTTPEnable )
			.indentedLine( "port:             " & serverInfo.port )
			.indentedLine( "SSLEnable:        " & serverInfo.SSLEnable )
			.indentedLine( "SSLport:          " & serverInfo.SSLport )
			.indentedLine( "rewritesEnable:   " & ( serverInfo.rewritesEnable ?: "false" ) )
			.indentedLine( "stopsocket:       " & serverInfo.stopsocket )
			.indentedLine( "logdir:           " & serverInfo.logDir )
			.indentedLine( "debug:            " & serverInfo.debug )
			.indentedLine( "ID:               " & serverInfo.id );

		if( len( serverInfo.libDirs ) ) { print.indentedLine( "libDirs:          " & serverInfo.libDirs ); }
		if( len( serverInfo.webConfigDir ) ) { print.indentedLine( "webConfigDir:     " & serverInfo.webConfigDir ); }
		if( len( serverInfo.serverConfigDir ) ) { print.indentedLine( "serverConfigDir:  " & serverInfo.serverConfigDir ); }
		if( len( serverInfo.webXML ) ) { print.indentedLine( "webXML:           " & serverInfo.webXML ); }
		if( len( serverInfo.trayicon ) ) { print.indentedLine( "trayicon:         " & serverInfo.trayicon ); }
		if( len( serverInfo.serverConfigFile ) ) { print.indentedLine( "serverConfigFile: " & serverInfo.serverConfigFile ); }
	}

	/**
	 * Print out a status color according to status and our status map
	 * @status The status
	 *
	 * @return The status color to print
	 */
	function getStatusColor( required status ){
		return variables.statusColors.keyExists( arguments.status ) ? variables.statusColors[ arguments.status ] : 'yellow';
	}

	/**
	 * Is the incoming name matching the search term
	 *
	 * @name The target
	 * @searchTerm The search term
	 */
	boolean function matchesName( name, searchTerm ) {
		if( listLen( arguments.searchTerm ) > 1 ) {
			return listFindNoCase( arguments.searchTerm, arguments.name );
		} else {
			return findNoCase( arguments.searchTerm, arguments.name );
		}
	}

	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}


}
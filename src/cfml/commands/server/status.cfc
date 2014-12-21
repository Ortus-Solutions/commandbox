/**
 * Show status of embedded server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server status
 * server status --showAll
 * server status name=serverName
 * {code}  
 **/
component extends="commandbox.system.BaseCommand" aliases="status" excludeFromHelp=false {

	// DI
	property name="serverService" inject="ServerService";
	
	/**
	 * Show server status
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @showAll.hint show all server statuses found
	 **/
	function run( directory="", name="", boolean showAll=false ){
		var servers = serverService.getServers();

		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		for( var thisKey in servers ){
			var thisServerInfo = servers[ thisKey ];

			// check if same as directory root
			if( arguments.directory != "" && thisServerInfo.webroot != arguments.directory && !arguments.showAll )
				continue;
			// check if same as short name
			if( arguments.name != "" && thisServerInfo.name != arguments.name && !arguments.showAll )
				continue;
			// Null Checks, to guarnatee correct struct.
			structAppend( thisServerInfo, serverService.newServerInfoStruct(), false );

			// Print Information
			print.line().yellowLine( "name: " & thisServerInfo.name )
				.string("  status: " );

			if(thisServerInfo.status eq "running") {
				print.greenLine( "running" )
					.line( "  info: " & thisServerInfo.statusInfo.result );
			} else if (thisServerInfo.status eq "starting") {
				print.yellowLine( "starting" )
					.redLine( "  info: " & thisServerInfo.statusInfo.result );
			} else if (thisServerInfo.status eq "unknown") {
				print.redLine( "unknown" )
					.redLine( "  info: " & thisServerInfo.statusInfo.result );
			} else {
				print.line( thisServerInfo.status );
			}

			print.line( "  webroot: " & thisServerInfo.webroot )
				.line( "  logdir: " & thisServerInfo.logDir )
				.line( "  libDirs: " & thisServerInfo.libDirs )
				.line( "  webConfigDir: " & thisServerInfo.webConfigDir )
				.line( "  serverConfigDir: " & thisServerInfo.serverConfigDir )
				.line( "  webXML: " & thisServerInfo.webXML )
				.line( "  trayicon: " & thisServerInfo.trayicon )
				.line( "  port: " & thisServerInfo.port )
				.line( "  host: " & thisServerInfo.host )
				.line( "  stopsocket: " & thisServerInfo.stopsocket )
				.line( "  debug: " & thisServerInfo.debug )
				.line( "  ID: " & thisServerInfo.id );
		}

		// No servers found, then do nothing
		if( structCount( servers ) eq 0 ){
			print.boldRedLine( "No server configurations found!" );
		}
	}

}
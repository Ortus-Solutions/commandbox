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
	function run( String directory="", String name="", boolean showAll=false ){
		var servers = serverService.getServers();

		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		for( var serverKey in servers ){
			var serv = servers[ serverKey ];
			// check if same as directory root
			if( arguments.directory != "" && serv.webroot != arguments.directory && !arguments.showAll )
				continue;
			// check if same as short name
			if( arguments.name != "" && serv.name != arguments.name && !arguments.showAll )
				continue;
			
			if( isNull( serv.statusInfo.result ) ){
				serv.statusInfo.result = "";
			}

			print.line().yellowLine( "name: " & serv.name )
				.string("  status: " );

			if(serv.status eq "running") {
				print.greenLine( "running" )
					.line( "  info: " & serv.statusInfo.result );
			} else if (serv.status eq "starting") {
				print.yellowLine( "starting" )
					.redLine( "  info: " & serv.statusInfo.result );
			} else if (serv.status eq "unknown") {
				print.redLine( "unknown" )
					.redLine( "  info: " & serv.statusInfo.result );
			} else {
				print.line( serv.status );
			}

			print.line( "  webroot: " & serv.webroot )
				.line( "  logdir: " & serv.logDir )
				.line( "  libDirs: " & serv.libDirs )
				.line( "  webConfigDir: " & serv.webConfigDir )
				.line( "  serverConfigDir: " & serv.serverConfigDir )
				.line( "  webXML: " & serv.webXML )
				.line( "  trayicon: " & serv.trayicon )
				.line( "  port: " & serv.port )
				.line( "  stopsocket: " & serv.stopsocket )
				.line( "  debug: " & serv.debug );
		}

		if( structCount( servers ) eq 0 ){
			print.boldRedLine( "No server configurations found!" );
		}
	}

}
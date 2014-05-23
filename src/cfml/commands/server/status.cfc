/**
 * Show server status
 **/
component extends="commandbox.system.BaseCommand" aliases="status" excludeFromHelp=false {

	property name="serverService" inject="ServerService";
	
	/**
	 * Show server status
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 **/
	function run( String directory="", String name="" ){
		var servers = serverService.getServers();

		arguments.directory = fileSystemUtil.resolveDirectory( arguments.directory );

		for( var serverKey in servers ){
			var serv = servers[ serverKey ];
			if( arguments.directory != "" && serv.webroot != arguments.directory )
				continue;
			if( arguments.name != "" && serv.name != arguments.name )
				continue;
			if( isNull( serv.statusInfo.reslut ) ){
				serv.statusInfo.reslut = "";
			}

			print.yellowLine( "name: " & serv.name )
				.string("  status: " );

			if(serv.status eq "running") {
				print.greenLine( "running" )
					.line( "  info: " & serv.statusInfo.reslut );
			} else if (serv.status eq "starting") {
				print.yellowLine( "starting" )
					.redLine( "  info: " & serv.statusInfo.reslut );
			} else if (serv.status eq "unknown") {
				print.redLine( "unknown" )
					.redLine( "  info: " & serv.statusInfo.reslut );
			} else {
				print.line( serv.status );
			}

			print.Line( "  webroot: " & serv.webroot )
				.line( "  port: " & serv.port )
				.line( "  stopsocket: " & serv.stopsocket )
		}
	}

}
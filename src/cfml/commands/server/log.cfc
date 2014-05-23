/**
 * Show server log
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	property name="serverService" inject="ServerService";

	/**
	 * Show server log
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 **/
	function run( String directory="", String name="" ){
		var webroot 	= arguments.directory is "" ? shell.pwd() : arguments.directory;
		var serverInfo 	= serverService.getServerInfo( fileSystemUtil.resolveDirectory( webroot ) );
		var logfile 	= serverInfo.logdir & "/server.out.txt";

		if( fileExists( logfile) ){
			return fileRead( logfile );
		} else {
			print.boldRedLine( "No log file found for '#webroot#'!" )
				.line( "#logFile#" );
		}
	}

}
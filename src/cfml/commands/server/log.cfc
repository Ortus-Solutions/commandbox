/**
 * Show server log
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	/**
	 * Show log
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 **/
	function run( String directory="", String name="" ){
		var manager 	= new commandbox.system.services.ServerService( shell );
		var webroot 	= arguments.directory is "" ? shell.pwd() : arguments.directory;
		var serverInfo 	= manager.getServerInfo( fileSystemUtil.resolveDirectory( webroot ) );
		var logfile 	= serverInfo.logdir & "/server.out.txt";

		if( fileExists( logfile) ){
			return fileRead( logfile );
		} else {
			printRed( "No log file found!" );
		}
	}

}
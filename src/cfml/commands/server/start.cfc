/**
 * Start a CFMLserver
 **/
component extends="commandbox.system.BaseCommand" aliases="start" excludeFromHelp=false {

	property name="serverService" inject="ServerService";
	
	/**
	 * @port.hint port number
	 * @openbrowser.hint open a browser after starting
	 * @directory.hint web root for this server
	 * @name.hint short name for this server
	 * @stopPort.hint stop socket listener port number
	 * @force.hint force start if status is not stopped
	 * @debug.hint sets debug log level
	 **/
	function run( 
		Numeric port=0,
		Boolean openbrowser=true,
		String directory="",
		String name="",
		Numeric stopPort=0,
		Boolean force=false,
		Boolean debug=false
	){
		var webroot = arguments.directory is "" ? shell.pwd() : arguments.directory;
		var name = arguments.name is "" ? listLast( webroot, "\/" ) : arguments.name;
		webroot = fileSystemUtil.resolveDirectory( webroot );
		var serverInfo = serverService.getServerInfo( webroot );
		// we don't want to changes the ports if we're doing stuff already
		if( serverInfo.status is "stopped" || arguments.force ){
			serverInfo.name = name;
			serverInfo.port = arguments.port;
			serverInfo.stopsocket = arguments.stopPort;
		}
		serverInfo.webroot = webroot;
		serverInfo.debug = arguments.debug;
		return serverService.start( serverInfo, arguments.openbrowser, arguments.force, arguments.debug );
	}

}
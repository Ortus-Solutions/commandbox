/**
 * Start a CFMLserver
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="start" excludeFromHelp=false {

	/**
	 * @openbrowser.hint open a browser after starting
	 * @directory.hint web root for this server
	 * @name.hint short name for this server
	 * @port.hint port number
	 * @stopsocket.hint stop socket listener port number
	 * @force.hint force start if status is not stopped
	 * @debug.hint sets debug log level
	 **/
	function run(Boolean openbrowser=false, String directory="", String name="", Numeric port=0, Numeric stopsocket=0, Boolean force=false, Boolean debug=false)  {
		var manager = new commandbox.system.services.ServerService(shell);
		var webroot = directory is "" ? shell.pwd() : directory;
		var name = name is "" ? listLast(webroot,"\/") : name;
		webroot = fileSystemUtil.resolveDirectory( webroot );
		var serverInfo = manager.getServerInfo(webroot);
		// we don't want to changes the ports if we're doing stuff already
		if(serverInfo.status is "stopped" || force) {
			serverInfo.name = name;
			serverInfo.port = port;
			serverInfo.stopsocket = stopsocket;
		}
		serverInfo.webroot = webroot;
		serverInfo.debug = debug;
		return manager.start(serverInfo, openbrowser, force, debug);
	}

}
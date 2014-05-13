/**
* I manage servers
**/
component {

	java = {
		ServerSocket : createObject("java","java.net.ServerSocket")
		, Socket : createObject("java","java.net.Socket")
		, InetAddress : createObject("java","java.net.InetAddress")
		, LaunchUtil : createObject("java","runwar.LaunchUtil")
		, LoaderCLIMain : createObject("java","cliloader.LoaderCLIMain")
	}

	function init(shell) {
		variables.shell = shell;
		variables.libdir = shell.getHomeDir() & "/lib";
		return this;
	}

	/**
	 * Start a server instance
	 *
	 * @openbrowser.hint open a browser after starting
	 * @directory.hint web root for this server
	 * @name.hint short name for this server
	 * @port.hint port number
	 * @stopsocket.hint stop socket listener port number
	 * @force.hint force start if status is not stopped
	 * @debug.hint sets debug log level
	 **/
	function start(Struct serverInfo, Boolean openBrowser, Boolean force=false, Boolean debug=false)  {
		var launchUtil = java.LaunchUtil;
		var cliClass = java.LoaderCLIMain;
		var webroot = serverInfo.webroot;
		var webhash = hash(serverInfo.webroot);
		var name = serverInfo.name is "" ? listLast(webroot,"\/") : serverInfo.name;
		var portNumber = serverInfo.port is 0 ? getRandomPort() : serverInfo.port;
		var socket = serverInfo.stopsocket is 0 ? getRandomPort() : serverInfo.stopsocket;
		var command = launchUtil.getJreExecutable();
		var cliPath = cliClass.class.getProtectionDomain().getCodeSource().getLocation().getPath();
		var logdir = shell.getHomeDir() & "/server/log/" & name;
		var processName = name is "" ? "CommandBox" : name;
		var args = "-jar #cliPath# -server --port #portNumber# --background true --debug #debug#"
				& " --stop-port #socket# --processname ""#processName#"" --log-dir #logdir#"
				& " --open-browser #openbrowser# --open-url http://127.0.0.1:#portNumber#"
				& " --libdir ""#variables.libdir#"" #webroot#";
		serverInfo.port = portNumber;
		serverInfo.stopsocket = socket;
		serverInfo.logdir = logdir;
		if(!directoryExists(logdir)) {
			directoryCreate(logdir,true);
		}
		setServerInfo(serverInfo);
		if(serverInfo.status == "stopped" || force) {
			serverInfo.status = "starting";
			setServerInfo(serverInfo);
			thread name="server#webhash##createUUID()#" serverInfo=serverInfo command=command args=args {
				try{
					execute name=command arguments=args timeout="50" variable="executeResult";
					serverInfo.statusInfo = {command:command,arguments:args,result:executeResult};
					serverInfo.status="running";
					setServerInfo(serverInfo);
				} catch (any e) {
					try{
						stop(serverInfo);
					} catch (any ex) {}
					serverInfo.statusInfo = {command:command,arguments:args,result:executeResult};
					serverInfo.status="stopped";
					setServerInfo(serverInfo);
				}
			}
			return "The server for #webroot# is starting on port #portNumber#... type 'server status' to see result";
		} else {
			return "Cannot start!  The server is currently in the #serverInfo.status# state!";
		}
	}

	/**
	 * Stop server
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function stop(Struct serverInfo)  {
		var launchUtil = java.LaunchUtil;
		var cliClass = java.LoaderCLIMain;
		var command = launchUtil.getJreExecutable();
		var cliPath = cliClass.class.getProtectionDomain().getCodeSource().getLocation().getPath();
		var stopsocket = serverInfo.stopsocket;
		var args = "-jar #cliPath# -stop --stop-port #val(stopsocket)# --background false";
		try{
			execute name=command arguments=args timeout="50" variable="executeResult";
			serverInfo.status = "stopped";
			serverInfo.statusInfo = {command:command,arguments:args,result:executeResult};
			setServerInfo(serverInfo);
			return executeResult;
		} catch (any e) {
			serverInfo.status = "unknown";
			serverInfo.statusInfo = {command:command,arguments:args,result:executeResult & e.message};
			setServerInfo(serverInfo);
			return e.message;
		}
	}

	/**
	 * Forget server
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @all.hint remove ALL servers
	 * @force.hint force
 	 **/
	function forget(Struct serverInfo, Boolean all=false, Boolean force=false)  {
		var shell = new Shell();
		if(!all) {
			if(shell.ask("Are you sure you wish to forget: "
					& serverInfo.name &":" & serverInfo.webroot & "? (Y/N) :") == "y") {
				servers = getServers();
				structDelete(servers,hash(serverInfo.webroot));
				setServers(servers);
			}
		} else {
			if(shell.ask("Are you sure you wish to forget ALL servers? (Y/N) :") == "y") {
				setServers({});
			}
		}
	}

	/**
	 * Get a random port for the specified host
	 * @host.hint host to get port on, defaults 127.0.0.1
 	 **/
	function getRandomPort(host="127.0.0.1") {
		var nextAvail = java.ServerSocket.init(0, 1, java.InetAddress.getByName(host));
		var portNumber = nextAvail.getLocalPort();
		nextAvail.close();
		return portNumber;
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo(Struct serverInfo) {
		// TODO: prevent race conditions  :)
		var servers = getServers();
		var webrootHash = hash(serverInfo.webroot);
		if(serverInfo.webroot == "") {
			throw("The webroot cannot be empty!");
		}
		servers[webrootHash] = serverInfo;
		setServers(servers);
	}

	/**
	 * persist servers
	 * @servers.hint struct of serverInfos
 	 **/
	function setServers(Struct servers) {
		// TODO: prevent race conditions  :)
		var serverConfig = "config/servers.json";
		fileWrite(serverConfig,shell.formatJson(serializeJSON(servers)));
	}

	/**
	 * get servers struct
 	 **/
	function getServers() {
		var serverConfig = "config/servers.json";
		if(fileExists(serverConfig)) {
			return deserializeJSON(fileRead(serverConfig));
		} else {
			return {};
		}
	}

	/**
	 * Get server info for webroot
	 * @webroot.hint root directory for served content
 	 **/
	function getServerInfo(webroot) {
		var servers = getServers();
		var webrootHash = hash(webroot);
		var statusInfo = {};
		if(!directoryExists(webroot)) {
			statusInfo = {result:"Webroot does not exist, cannot start :" & webroot };
		}
		if(isNull(servers[webrootHash])) {
			servers[webrootHash] = {
				webroot:webroot,
				port:"",
				stopsocket:"",
				debug:false,
				status:"stopped",
				statusInfo:{result:""},
				name:listLast(webroot,"\/")
			}
			setServers(servers);
		}
		return servers[webrootHash];
	}

}
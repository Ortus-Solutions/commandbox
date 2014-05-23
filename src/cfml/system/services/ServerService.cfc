/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I manage servers
*
*/
component singleton {
	
	// DI
	property name="shell" 			inject="shell";
	property name="formatterUtil" 	inject="Formatter";
	property name="fileSystemUtil" 	inject="FileSystem";

	/**
	* Where we store server information
	*/
	property name="serverConfig";

	function init(){
		// the lib dir location, populated from shell later.
		variables.libDir = "";
		// Where server configs are stored
		variables.serverConfig 	= "/commandbox/system/config/servers.json";
		// if not exists, init with empty struct
		if( !fileExists( serverConfig ) ){
			setServers( {} );
		}
		// java helpers
		java = {
			ServerSocket : createObject("java","java.net.ServerSocket")
			, File : createObject("java","java.io.File")
			, Socket : createObject("java","java.net.Socket")
			, InetAddress : createObject("java","java.net.InetAddress")
			, LaunchUtil : createObject("java","runwar.LaunchUtil")
		};

		return this;
	}

	function onDIComplete() {
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
		var webroot = serverInfo.webroot;
		var webhash = hash(serverInfo.webroot);
		var name = serverInfo.name is "" ? listLast(webroot,"\/") : serverInfo.name;
		var portNumber = serverInfo.port == 0 ? getRandomPort() : serverInfo.port;
		var socket = serverInfo.stopsocket == 0 ? getRandomPort() : serverInfo.stopsocket;
		var jarPath = java.File.init(launchUtil.class.getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart()).getAbsolutePath();
		var logdir = shell.getHomeDir() & "/server/log/" & name;
		var processName = name is "" ? "cfml" : name;
		var command = fileSystemUtil.getJREExecutable();
		var args = "-javaagent:""#libdir#/railo-inst.jar"" -jar ""#jarPath#"""
				& " -war ""#webroot#"" --background=true --port #portNumber# --debug #debug#"
				& " --stop-port #socket# --processname ""#processName#"" --log-dir ""#logdir#"""
				& " --open-browser #openbrowser# --open-url http://127.0.0.1:#portNumber#"
				& " --libdir ""#variables.libdir#"" --iconpath ""#variables.libdir#/trayicon.png""";
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
					serverInfo.statusInfo.result &= executeResult;
					serverInfo.status="unknown";
					setServerInfo(serverInfo);
				}
			}
			return "The server for #webroot# is starting on port #portNumber#... type 'server status' to see result";
		} else {
			return "Cannot start!  The server is currently in the #serverInfo.status# state!#chr(10)#Use force=true or the 'server forget' command ";
		}
	}

	/**
	 * Stop server
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function stop(Struct serverInfo)  {
		var launchUtil = java.LaunchUtil;
		var jarPath = java.File.init(launchUtil.class.getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart()).getAbsolutePath();
		var command = fileSystemUtil.getJREExecutable();
		var stopsocket = serverInfo.stopsocket;
		var args = "-jar ""#jarPath#"" -stop --stop-port #val(stopsocket)# --background false";
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
	 * Forget server from the configurations
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @all.hint remove ALL servers
 	 **/
	function forget( required Struct serverInfo, Boolean all=false ){
		if( !all ){
			var servers = getServers();
			structDelete( servers, hash( arguments.serverInfo.webroot ) );
			setServers( servers );
		} else {
			setServers( {} );
		}
	}

	/**
	 * Get a random port for the specified host
	 * @host.hint host to get port on, defaults 127.0.0.1
 	 **/
	function getRandomPort( host="127.0.0.1" ){
		var nextAvail  = java.ServerSocket.init( javaCast( "int", 0 ), 
												 javaCast( "int", 1 ), 
												 java.InetAddress.getByName( arguments.host ) );
		var portNumber = nextAvail.getLocalPort();
		nextAvail.close();
		return portNumber;
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo( required Struct serverInfo ){
		var servers 	= getServers();
		var webrootHash = hash( arguments.serverInfo.webroot );
		
		if( arguments.serverInfo.webroot == "" ){
			throw( "The webroot cannot be empty!" );
		}
		servers[ webrootHash ] = serverInfo;
		// persist back safely
		setServers( servers );
	}

	/**
	 * persist servers
	 * @servers.hint struct of serverInfos
 	 **/
	function setServers( required Struct servers ){
		// TODO: prevent race conditions  :)
		lock name="serverservice.serverconfig" type="exclusive" throwOnTimeout="true" timeout="10"{
			fileWrite( serverConfig, formatterUtil.formatJson( serializeJSON( servers ) ) );
		}
	}

	/**
	 * get servers struct from config file
 	 **/
	function getServers() {
		if( fileExists( variables.serverConfig ) ){
			lock name="serverservice.serverconfig" type="readOnly" throwOnTimeout="true" timeout="10"{
				return deserializeJSON( fileRead( variables.serverConfig ) );
			}
		} else {
			return {};
		}
	}

	/**
	 * Get server info for webroot
	 * @webroot.hint root directory for served content
 	 **/
	function getServerInfo( required webroot ){
		var servers 	= getServers();
		var webrootHash = hash( arguments.webroot );
		var statusInfo 	= {};

		if( !directoryExists( arguments.webroot ) ){
			statusInfo = { result:"Webroot does not exist, cannot start :" & arguments.webroot };
		}
		if( isNull( servers[ webrootHash ] ) ){
			servers[ webrootHash ] = {
				webroot		: arguments.webroot,
				port		: "",
				stopsocket	: "",
				debug		: false,
				status		: "stopped",
				statusInfo	: { result : "" },
				name		: listLast( arguments.webroot, "\/" )
			}
			setServers( servers );
		}
		return servers[ webrootHash ];
	}

}
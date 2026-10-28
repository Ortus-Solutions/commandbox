/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* I am an interceptor that listens to all the server interception points and runs server scripts for them if they exist.
*
*/
component {
	property name="serverService"		inject="ServerService";
	property name="shell"				inject="shell";

	function init() {
		variables.inScript=false;
	}

	function preServerStart() { processScripts( 'preServerStart', shell.pwd(), interceptData ); }
	function onServerInstall() { processScripts( 'onServerInstall', interceptData.serverinfo.webroot, interceptData ); }
	function onServerInitialInstall() { processScripts( 'onServerInitialInstall', interceptData.serverinfo.webroot, interceptData ); }
	function onServerStart() { processScripts( 'onServerStart', interceptData.serverinfo.webroot, interceptData ); }
	function onServerStop() { processScripts( 'onServerStop', interceptData.serverinfo.webroot, interceptData ); }
	function preServerForget() { processScripts( 'preServerForget', interceptData.serverinfo.webroot, interceptData ); }
	function postServerForget() { processScripts( 'postServerForget', interceptData.serverinfo.webroot, interceptData ); }

	function processScripts( required string interceptionPoint, string directory=shell.pwd(), interceptData={} ) {
		inScript=true;
		try {
			serverService.runScript( arguments.interceptionPoint, arguments.directory, true, interceptData );
		} finally {
			inScript=false;
		}
	}

}

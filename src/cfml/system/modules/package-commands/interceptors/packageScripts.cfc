/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* I am an interceptor that listens to all the interception points and runs package scripts for them if they exist.
*
*/
component {
	property name="packageService"		inject="packageService";
	property name="shell"				inject="shell";
	property name='consoleLogger'		inject='logbox:logger:console';
	
	function onCLIStart() { processScripts( 'onCLIStart' ); }
	function onCLIExit() { processScripts( 'onCLIExit' ); }
	function preCommand() { processScripts( 'preCommand' ); }
	function postCommand() { processScripts( 'postCommand' ); }
	function preModuleLoad() { processScripts( 'preModuleLoad' ); }
	function postModuleLoad() { processScripts( 'postModuleLoad' ); }
	function preModuleUnLoad() { processScripts( 'preModuleUnLoad' ); }
	function postModuleUnload() { processScripts( 'postModuleUnload' ); }
	function onServerStart() { processScripts( 'onServerStart', interceptData.serverinfo.webroot ); }
	function onServerStop() { processScripts( 'onServerStop', interceptData.serverinfo.webroot ); }
	function onException() { processScripts( 'onException' ); }
	function preInstall() { processScripts( 'preInstall' ); }
	function postInstall() { processScripts( 'postInstall' ); }
	function preUninstall() { processScripts( 'preUninstall' ); }
	function postUninstall() { processScripts( 'postUninstall' ); }
	function preVersion() { processScripts( 'preVersion' ); }
	function postVersion() { processScripts( 'postVersion' ); }
	function prePublish() { processScripts( 'prePublish' ); }
	function postPublish() { processScripts( 'postPublish' ); }
	
	function processScripts( required string interceptionPoint, string directory=shell.pwd() ) {
		packageService.runScript( arguments.interceptionPoint, arguments.directory );
	}
		
}
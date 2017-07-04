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

	function preServerStart() { processScripts( 'preServerStart' ); }
	function onServerInstall() { processScripts( 'onServerInstall', interceptData.serverinfo.webroot ); }
	function onServerStart() { processScripts( 'onServerStart', interceptData.serverinfo.webroot ); }
	function onServerStop() { processScripts( 'onServerStop', interceptData.serverinfo.webroot ); }
	function preServerForget() { processScripts( 'preServerForget', interceptData.serverinfo.webroot ); }
	function postServerForget() { processScripts( 'postServerForget', interceptData.serverinfo.webroot ); }

	function onException() { processScripts( 'onException' ); }

	// preInstall gets package requesting the installation because dep isn't installed yet
	function preInstall() { processScripts( 'preInstall', interceptData.packagePathRequestingInstallation ); }

	// onInstall gets package requesting the installation because dep isn't installed yet
	function onInstall() { processScripts( 'onInstall', interceptData.packagePathRequestingInstallation ); }

	// postInstall runs in the newly installed package
	function postInstall() { processScripts( 'postInstall', interceptData.installDirectory ); }

	// preUninstall runs in the package that's about to be uninstalled
	function preUninstall() { processScripts( 'preUninstall', interceptData.uninstallDirectory ); }

	// postUninstall gets package that requested uninstallation because dep isn't there any longer
	function postUninstall() { processScripts( 'postUninstall', interceptData.uninstallArgs.packagePathRequestingUninstallation ); }

	function preVersion() { processScripts( 'preVersion' ); }
	function postVersion() { processScripts( 'postVersion' ); }
	function onRelease() { processScripts( 'onRelease' ); }
	function prePublish() { processScripts( 'prePublish' ); }
	function postPublish() { processScripts( 'postPublish' ); }

	function processScripts( required string interceptionPoint, string directory=shell.pwd() ) {
		packageService.runScript( arguments.interceptionPoint, arguments.directory );
	}

}

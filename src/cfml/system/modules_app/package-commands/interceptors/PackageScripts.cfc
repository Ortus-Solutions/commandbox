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

	function init() {
		variables.inScript=false;
	}

	function onCLIStart() { processScripts( 'onCLIStart', shell.pwd(), interceptData ); }
	function onCLIExit() { processScripts( 'onCLIExit', shell.pwd(), interceptData ); }
	function prePrompt() { processScripts( 'prePrompt', shell.pwd(), interceptData ); }

	function preProcessLine() { processScripts( 'preProcessLine', shell.pwd(), interceptData ); }
	function postProcessLine() { processScripts( 'postProcessLine', shell.pwd(), interceptData ); }
	function preCommand() {
		// quick check to prevent nasty recursion
		if( !inScript ) {
			processScripts( 'preCommand', shell.pwd(), interceptData );
		}
	}
	function postCommand() {
		// quick check to prevent nasty recursion
		if( !inScript ) {
			processScripts( 'postCommand', shell.pwd(), interceptData );
		}
	}
	function preModuleLoad() { processScripts( 'preModuleLoad', shell.pwd(), interceptData ); }
	function postModuleLoad() { processScripts( 'postModuleLoad', shell.pwd(), interceptData ); }
	function preModuleUnLoad() { processScripts( 'preModuleUnLoad', shell.pwd(), interceptData ); }
	function postModuleUnload() { processScripts( 'postModuleUnload', shell.pwd(), interceptData ); }

	function preServerStart() { processScripts( 'preServerStart', shell.pwd(), interceptData ); }
	function onServerInstall() { processScripts( 'onServerInstall', interceptData.serverinfo.webroot, interceptData ); }
	function onServerStart() { processScripts( 'onServerStart', interceptData.serverinfo.webroot, interceptData ); }
	function onServerStop() { processScripts( 'onServerStop', interceptData.serverinfo.webroot, interceptData ); }
	function preServerForget() { processScripts( 'preServerForget', interceptData.serverinfo.webroot, interceptData ); }
	function postServerForget() { processScripts( 'postServerForget', interceptData.serverinfo.webroot, interceptData ); }

	function onException() { processScripts( 'onException', shell.pwd(), interceptData ); }

	// preInstall gets package requesting the installation because dep isn't installed yet
	function preInstall() { processScripts( 'preInstall', interceptData.packagePathRequestingInstallation, interceptData ); }

	function preInstallAll() { processScripts( 'preInstallAll', shell.pwd(), interceptData ); }

	// onInstall gets package requesting the installation because dep isn't installed yet
	function onInstall() { processScripts( 'onInstall', interceptData.packagePathRequestingInstallation, interceptData  ); }

	// postInstall runs in the newly installed package
	function postInstall() { processScripts( 'postInstall', interceptData.installDirectory, interceptData  ); }

	function postInstallAll() { processScripts( 'postInstallAll', shell.pwd(), interceptData ); }

	// preUninstall runs in the package that's about to be uninstalled
	function preUninstall() { processScripts( 'preUninstall', interceptData.uninstallDirectory, interceptData  ); }

	// postUninstall gets package that requested uninstallation because dep isn't there any longer
	function postUninstall() { processScripts( 'postUninstall', interceptData.uninstallArgs.packagePathRequestingUninstallation, interceptData  ); }

	function preVersion() { processScripts( 'preVersion', shell.pwd(), interceptData ); }
	function postVersion() { processScripts( 'postVersion', shell.pwd(), interceptData ); }
	function onRelease() { processScripts( 'onRelease', shell.pwd(), interceptData ); }
	function prePublish() { processScripts( 'prePublish', shell.pwd(), interceptData ); }
	function postPublish() { processScripts( 'postPublish', shell.pwd(), interceptData ); }

	function processScripts( required string interceptionPoint, string directory=shell.pwd(), interceptData={} ) {
		inScript=true;
		try {
			packageService.runScript( arguments.interceptionPoint, arguments.directory, true, interceptData );
		} finally {
			inScript=false;
		}
	}

}

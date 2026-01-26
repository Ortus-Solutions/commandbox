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
	}

	/**
	 * Interceptor for post-installation events
	 *
	 * Intercept data:
	 * - installArgs
	 * - installDirectory
	 * - system (shellWillReload)
	 */
	function postInstall( Struct interceptData ){
		var packageService = wirebox.getInstance( "packageService" );
		var boxJSON        = packageService.readPackageDescriptor( interceptData.installDirectory );
		if ( boxJSON.type == "commandbox-modules" ) {
			var executables = boxJSON.executables ?: {};
			if( !isStruct( executables ) ){
				consoleLogger.warn( "The 'executables' entry in box.json for commandbox-modules must be a struct of alias/commandText pairs. Skipping executable alias creation." );
				return;
			}
			for( executable in executables ) {
				var commandText = executables[ executable ];
				wirebox
					.getInstance(
						name          = "CommandDSL",
						initArguments = { name : "executable create" }
					)
					.params(
						alias       = executable,
						commandText = "box #trim( commandText )#"
					)
					.run();
			}
		}
	}

	/**
	 * Interceptor for pre-uninstallation events
	 *
	 * Removes the executable alias when a CommandBox module is being uninstalled.
	 *
	 * Intercept data:
	 * - uninstallDirectory
	 * - uninstallArgs
	 */
	function preUninstall( Struct interceptData ){
		var packageService = wirebox.getInstance( "packageService" );
		var boxJSON        = packageService.readPackageDescriptor( interceptData.uninstallDirectory );
		if ( boxJSON.type == "commandbox-modules" ) {
			var executables = boxJSON.executables ?: {};
			if( !isStruct( executables ) ){
				consoleLogger.warn( "The 'executables' entry in box.json for commandbox-modules must be a struct of alias/commandText pairs. Skipping executable alias removal." );
				return;
			}
			for( executable in executables ) {
				wirebox
					.getInstance(
						name          = "CommandDSL",
						initArguments = { name : "executable delete" }
					)
					.params( executable )
					.run();
			}
		}
	}

}

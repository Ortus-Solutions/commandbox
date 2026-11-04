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
	property name='print'				inject='PrintBuffer';

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
			var executableService = wirebox.getInstance( "ExecutableService@system-commands" );
			for( executable in executables ) {
				var commandText = executables[ executable ];
				wirebox
					.getInstance(
						name          = "CommandDSL",
						initArguments = { name : "executable create" }
					)
					.params(
						alias       = executable,
						commandText = '"' & executableService.getBoxBinary() & '" ' & trim( commandText )
					)
					.run();
			}
			return;
		}

		// BoxLang modules declare their commands under the "boxlang" key, which is what the
		// BoxLang quick installers read when they create executables. Keep the same
		// behaviour here so CommandBox can replace those installers.
		if ( boxJSON.type == "boxlang-modules" ) {
			var boxlangSettings = boxJSON.boxlang ?: {};
			if( !isStruct( boxlangSettings ) ){
				consoleLogger.warn( "The 'boxlang' entry in box.json for boxlang-modules must be a struct. Skipping executable alias creation." );
				return;
			}

			var executableService = wirebox.getInstance( "ExecutableService@system-commands" );
			var moduleName        = resolveBoxLangModuleName( boxlangSettings, boxJSON, interceptData.installDirectory );

			// boxlang.executable - one launcher that runs the module itself
			var single = boxlangSettings.executable ?: '';
			if( isSimpleValue( single ) && len( trim( single ) ) ) {
				var location = executableService.createModuleAlias( trim( single ), moduleName );
				print.line( "Created executable alias [#trim( single )#] for module [#moduleName#] at location [#location#]" ).toConsole();
			}

			// boxlang.executables - the module supplies the script bodies verbatim
			var multiple = boxlangSettings.executables ?: {};
			if( isStruct( multiple ) && structCount( multiple ) ) {
				for( var execName in multiple ) {
					if( !len( trim( execName ) ) ) {
						continue;
					}
					var location = executableService.createRawAlias( trim( execName ), multiple[ execName ] );
					print.line( "Created executable alias [#trim( execName )#] at location [#location#]" ).toConsole();
				}
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
			return;
		}

		if ( boxJSON.type == "boxlang-modules" ) {
			var boxlangSettings = boxJSON.boxlang ?: {};
			if( !isStruct( boxlangSettings ) ){
				consoleLogger.warn( "The 'boxlang' entry in box.json for boxlang-modules must be a struct. Skipping executable alias removal." );
				return;
			}

			var executableService = wirebox.getInstance( "ExecutableService@system-commands" );
			for( var executable in getBoxLangExecutableNames( boxlangSettings ) ) {
				// A module script is written by createRawAlias and may have a .bat wrapper,
				// while boxlang.executable goes through the normal alias removal.
				var removed = executableService.removeAlias( executable ) || executableService.removeRawAlias( executable );
				if( removed ) {
					print.line( "Removed executable alias [#executable#]" ).toConsole();
				}
			}
		}
	}

	/**
	 * Work out the module name a launcher should run, preferring the module's own
	 * declaration and falling back to the installed directory, which mirrors how the
	 * BoxLang quick installers fall back to the module they were asked to install.
	 *
	 * @boxlangSettings The module's boxlang settings
	 * @boxJSON The parsed box.json
	 * @installDirectory Where the module was installed
	 */
	private string function resolveBoxLangModuleName(
		required struct boxlangSettings,
		required struct boxJSON,
		required string installDirectory
		) {
		var moduleName = arguments.boxlangSettings.moduleName ?: '';
		if( isSimpleValue( moduleName ) && len( trim( moduleName ) ) ) {
			return trim( moduleName );
		}

		var slug = arguments.boxJSON.slug ?: '';
		if( isSimpleValue( slug ) && len( trim( slug ) ) ) {
			return trim( slug );
		}

		return listLast( arguments.installDirectory.replace( '\', '/', 'all' ), '/' );
	}

	/**
	 * Get every executable name a module's boxlang settings declare.
	 *
	 * @boxlangSettings The module's boxlang settings
	 */
	private array function getBoxLangExecutableNames( required struct boxlangSettings ) {
		var names = [];

		var single = arguments.boxlangSettings.executable ?: '';
		if( isSimpleValue( single ) && len( trim( single ) ) ) {
			names.append( trim( single ) );
		}

		var multiple = arguments.boxlangSettings.executables ?: {};
		if( isStruct( multiple ) ) {
			for( var name in multiple ) {
				if( len( trim( name ) ) ) {
					names.append( trim( name ) );
				}
			}
		}

		return names;
	}

}

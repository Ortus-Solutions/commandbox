/**
 * Create a new module in an existing ColdBox application.  Make sure you are running this command in the root
 * of your app for it to find the correct folder.
 * .
 * {code:bash}
 * coldbox create module myModule
 * {code}
 *
 **/
component scope="noscope"{

	/**
	 * @name Name of the module to create.
	 * @author Whoever wrote this module
	 * @authorURL The author's URL
	 * @description The description for this module
	 * @version The semantic version number: major.minior.patch
	 * @cfmapping A CF app mapping to create that points to the root of this module
	 * @modelNamespace The namespace to use when mapping the models in this module
	 * @dependencies The list of dependencies for this module
	 * @directory The base directory to create your model in and creates the directory if it does not exist.
	 * @views Create the views folder on creatin or remove it. Defaults to true
	 **/
	function run(
		required name,
		author         = "",
		authorURL      = "",
		description    = "",
		version        = "1.0.0",
		cfmapping      = arguments.name,
		modelNamespace = arguments.name,
		dependencies   = "",
		directory      = "modules_app",
		boolean views  = true
	){
		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory );

		// Validate directory
		if ( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}
		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Read in Module Config
		var moduleConfig = fileRead( "/coldbox-commands/templates/modules/ModuleConfig.cfc" );

		// Start Generation Replacing
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@title@",
			arguments.name,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@author@",
			arguments.author,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@authorURL@",
			arguments.authorURL,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@description@",
			arguments.description,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@version@",
			arguments.version,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@cfmapping@",
			arguments.cfmapping,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@modelNamespace@",
			arguments.modelNamespace,
			"all"
		);
		moduleConfig = replaceNoCase(
			moduleConfig,
			"@dependencies@",
			serializeJSON( listToArray( arguments.dependencies ) ),
			"all"
		);

		// Confirm it
		if (
			directoryExists( arguments.directory & "/#arguments.name#" ) &&
			!confirm( "The module already exists, overwrite it (y/n)?" )
		) {
			print.redLine( "Exiting..." );
			return;
		}

		// Copy module template
		directoryCopy(
			"/coldbox-commands/templates/modules/",
			arguments.directory & "/#arguments.name#",
			true
		);

		// Remove or keep Views?
		if( !arguments.views ){
			directoryDelete( arguments.directory & "/#arguments.name#/views", true );
		}

		// Write Out the New Config
		fileWrite( arguments.directory & "/#arguments.name#/ModuleConfig.cfc", moduleConfig );

		// Output
		print.blueLine( "Created the (#arguments.name#) module at: " & arguments.directory );
		directoryList(
				arguments.directory & "/#arguments.name#",
				true,
				"path",
				( path ) => !reFindNoCase( "\.DS_Store", arguments.path )
			)
			.each( ( item ) => print.greenLine( "  => " & item.replace( directory, "" ) ) );
	}

}

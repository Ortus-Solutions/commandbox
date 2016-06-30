/**
* Create a new virtual entity service model in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.
* .
* {code:bash}
* coldbox create orm-virtual-service Contact --open
* {code}
*
 **/
component {

	/**
	* @entityName The name of the entity this virtual service will be bound to
	* @directory The base directory to create your model in and creates the directory if it does not exist.
	* @queryCaching Will you be activating query caching or not
	* @eventHandling Will the virtual entity service emit events
	* @cacheRegion The cache region the virtual entity service methods will use
	* @tests Generate the unit test BDD component
	* @testsDirectory Your unit tests directory. Only used if tests is true
	* @open Open the file once generated
	**/
	function run( 
		required entityName,
		directory="models",
		boolean queryCaching=false,
		boolean eventHandling=true,
		cacheRegion="",
		boolean tests=true,
		testsDirectory='tests/specs/unit',
		boolean open=false
	) {
		// non-canonical path
		var nonCanonicalDirectory 	= arguments.directory;
		// This will make each directory canonical and absolute
		arguments.directory 		= fileSystemUtil.resolvePath( arguments.directory );
		arguments.testsDirectory 	= fileSystemUtil.resolvePath( arguments.testsDirectory );

		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// Read in Template
		var modelContent 	 		= fileRead( '/coldbox-commands/templates/orm/VirtualEntityService.txt' );
		var modelTestContent 		= fileRead( '/coldbox-commands/templates/testing/ModelBDDContentScript.txt' );

		// Query cache Region
		if( !len( arguments.cacheRegion ) ){
			arguments.cacheRegion = "ormservice.#arguments.entityName#";
		}

		// Basic replacements
		modelContent 	 = replaceNoCase( modelContent, '|entityName|', arguments.entityname, 'all' );
		modelContent 	 = replaceNoCase( modelContent, '|QueryCaching|', arguments.QueryCaching, 'all' );
		modelContent 	 = replaceNoCase( modelContent, '|cacheRegion|', arguments.cacheRegion, 'all' );
		modelContent 	 = replaceNoCase( modelContent, '|eventHandling|', arguments.eventHandling, 'all' );
		modelTestContent = replaceNoCase( modelTestContent, '|modelName|', "#nonCanonicalDirectory#.#arguments.entityName#", 'all' );
		modelTestContent = replaceNoCase( modelTestContent, '|TestCases|', "", 'all');

		// Write out the model
		var modelPath = '#arguments.directory#/#arguments.entityName#Service.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( modelPath ), true, true );
		file action='write' file='#modelPath#' mode ='777' output='#modelContent#';
		print.greenLine( 'Created #modelPath#' );

		if( arguments.tests ) {
			var testPath = '#arguments.TestsDirectory#/#arguments.entityName#ServiceTest.cfc';
			// Create dir if it doesn't exist
			directorycreate( getDirectoryFromPath( testPath ), true, true );
			// Create the tests
			file action='write' file='#testPath#' mode ='777' output='#modelTestContent#';
			// open file
			if( arguments.open ){ openPath( testPath ); }			
			print.greenLine( 'Created #testPath#' );
		}

		// Open file?
		if( arguments.open ){ openPath( modelPath ); }			
	}

}
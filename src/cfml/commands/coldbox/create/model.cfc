/**
* This will create a new model CFC in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.  You can optionally create unit tests for your new model at the same time.
* By default, your new model will be created in /model but you can override that with the directory param.
* Once you create a model you can add a mapping for it in your WireBox binder, or use ColdBox's default scan location and
* just reference it with getModel( 'modelName' ).
*
 **/
component persistent='false' extends='commandbox.system.BaseCommand' aliases='' excludeFromHelp=false {

	variables.validPersistences = 'Transient,Singleton';

	/**
	* @name.hint Name of the model to create without the .cfc. For packages, specify name as 'myPackage/myModel'
	* @persistence.hint Specify singleton to have only one instance of this model created
	* @tests.hint Generate the unit test component
	* @testsDirectory.hint Your unit tests directory. Only used if tests is true
	* @directory.hint The base directory to create your model in.
	 **/
	function run( 	required name,
					persistence='transient',
					boolean tests=true,
					testsDirectory='tests/specs/unit',
					directory='model' ) {
		// This will make each directory canonical and absolute
		directory = fileSystemUtil.resolveDirectory( directory );
		testsDirectory = fileSystemUtil.resolveDirectory( testsDirectory );

		// Validate directory
		if( !directoryExists( directory ) ) {
			error( 'The directory [#directory#] doesn''t exist.' );
		}
		// Validate persistence
		if( !listFindNoCase( validPersistences, persistence ) ) {
			error( "The persistence value [#persistence#] is invalid. Valid values are [#listChangeDelims( validPersistences, ', ', ',' )#]" );
		}
		// Exit the command if something above failed
		if( hasError() ) {
			return;
		}


		// Allow dot-delimited paths
		name = replace( name, '.', '/', 'all' );
		defaultDescription = 'I am a new Model Object';
		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		var script = true;
		if( script ) {
			scriptPrefix = 'Script';
		}

		// Read in Template
		var modelContent = fileRead( '/commandbox/templates/ModelContent#scriptPrefix#.txt' );
		var modelTestContent = fileRead( '/commandbox/templates/testing/ModelBDDContent#scriptPrefix#.txt' );

		modelContent = replaceNoCase( modelContent, '|modelName|', listLast( name, '/\' ), 'all' );
		modelTestContent = replaceNoCase( modelTestContent, '|modelName|', listChangeDelims( name, '.', '/\' ), 'all' );

		// Placeholder in case we add this in
		Description = '';
		if( len( description ) ) {
			modelContent = replaceNoCase( modelContent, '|modelDescription|', Description, 'all' );
		} else {
			modelContent = replaceNoCase( modelContent, '|modelDescription|', defaultDescription, 'all' );
		}

		switch ( Persistence ) {
			case 'Transient' :
				modelContent = replaceNoCase( modelContent, '|modelPersistence|', '', 'all' );
				break;
			case 'Singleton' :
				modelContent = replaceNoCase( modelContent, '|modelPersistence|', 'singleton="true"', 'all');
		}

		// Write out the model
		var modelPath = '#directory#/#name#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( modelPath ), true, true );
		file action='write' file='#modelPath#' mode ='777' output='#modelContent#';
		print.greenLine( 'Created #modelPath#' );

		if( tests ) {
			var testPath = '#TestsDirectory#/#name#Test.cfc';
			// Create dir if it doesn't exist
			directorycreate( getDirectoryFromPath( testPath ), true, true );
			// Create the tests
			file action='write' file='#testPath#' mode ='777' output='#modelTestContent#';
			print.greenLine( 'Created #testPath#' );
		}

	}

}
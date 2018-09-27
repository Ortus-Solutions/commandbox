/**
* Create a new model bdd test in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.
* .
* {code:bash}
* coldbox create model-test myModel --open
* {code}
*
 **/
component {

	/**
	* Constructor
	*/
	function init(){
		// valid persistences
		variables.validPersistences = 'Transient,Singleton';

		return this;
	}

	/**
	* @path.hint The instantiation path of the model to create the test for without any .cfc
	* @methods.hint A comma-delimited list of method to generate tests for
	* @testsDirectory.hint Your unit tests directory. Only used if tests is true
	* @open.hint Open the file once generated
	**/
	function run(
		required path,
		methods="",
		testsDirectory='tests/specs/unit',
		boolean open=false
	) {
		// This will make each directory canonical and absolute
		arguments.testsDirectory = resolvePath( arguments.testsDirectory );

		// Validate directory
		if( !directoryExists( arguments.testsDirectory ) ) {
			directoryCreate( arguments.testsDirectory );
		}

		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Read in Template
		var modelTestContent 		= fileRead( '/coldbox-commands/templates/testing/ModelBDDContentScript.txt' );
		var modelTestMethodContent 	= fileRead( '/coldbox-commands/templates/testing/ModelBDDMethodContentScript.txt' );

		// Basic replacements
		modelTestContent = replaceNoCase( modelTestContent, '|modelName|', arguments.path, 'all' );

		// Handle Methods
		if( len( arguments.methods ) ){
			var allTestsCases   = "";

			// Loop Over methods to generate them
			for( var thisMethod in listToArray( arguments.methods ) ) {
				thisMethod = trim( thisMethod );

				var thisTestCase = replaceNoCase( modelTestMethodContent, '|method|', thisMethod, 'all' );
				allTestsCases &= thisTestCase & CR & CR;

				print.yellowLine( "Generated method: #thisMethod#");
			}

			// final replacement
			modelTestContent 	= replaceNoCase( modelTestContent, '|TestCases|', allTestsCases, 'all');
		} else {
			modelTestContent = replaceNoCase( modelTestContent, '|TestCases|', '', 'all' );
		}

		var testPath = '#arguments.TestsDirectory#/#listLast( arguments.path, "." )#Test.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( testPath ), true, true );

		// Confirm it
		if( fileExists( testPath ) && !confirm( "The file '#getFileFromPath( testPath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}

		// Create the tests
		file action='write' file='#testPath#' mode ='777' output='#modelTestContent#';
		// open file
		if( arguments.open ){ openPath( testPath ); }
		print.greenLine( 'Created #testPath#' );
		// Open file?
		if( arguments.open ){ openPath( testPath ); }
	}

}

/**
* Create a new integration spec in an existing ColdBox-enabled application.  Run this command in the root
* of your app for it to find the correct folder.  By default, your new test spec will be created in /tests/specs/integration but you can
* override that with the directory param as well.  You can also choose your testing style: BDD or xUnit.
* .
* {code:bash}
* #Generate a handler integration spec using BDD
* coldbox create integration-test contacts
* {code}
* .
* {code:bash}
* #Generate a handler integration spec using BDD and open the file
* coldbox create integration-test contacts --open
* {code}
* .
* {code:bash}
* #Generate a handler integration spec using BDD with several actions
* coldbox create integration-test contacts index,save,delete
* {code}
* .
* {code:bash}
* #Generate a handler integration spec using xUnit
* coldbox create integration-test contacts --xunit
* {code}
**/
component {

	/**
	* @handler.hint Name of the handler to test
	* @actions.hint A comma-delimited list of actions to generate
	* @appMapping.hint The root location of the application in the web root: ex: /MyApp or / if in the root
	* @bdd.hint Defaults to BDD style
	* @xunit.hint You can alternatively use xUnit style
	* @open.hint Open the file once it is created
	* @script.hint Generate content in script markup or tag markup
	* @directory.hint The base directory to create your test spec in and creates the directory if it does not exist. Defaults to 'tests/specs/integration'
	**/
	function run(
		required handler,
		actions="",
		appMapping="/",
		boolean bdd=true,
		boolean xunit=false,
		boolean open=false,
		boolean script=true,
		directory="tests/specs/integration"
	){

		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}
		// Exit the command if something above failed
		if( hasError() ) {
			return;
		}

		// Allow dot-delimited paths
		arguments.handler = replace( arguments.handler, '.', '/', 'all' );
		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		if( arguments.script ) {
			scriptPrefix = 'Script';
		}

		// Style?
		var stylePrefix = 'BDD';
		if( arguments.xunit OR !arguments.bdd ) {
			stylePrefix = 'Test';
		}

		// Read in Templates
		var handlerTestContent 		= fileRead( '/coldbox-commands/templates/testing/Handler#stylePrefix#Content#scriptPrefix#.txt' );
		var handlerTestCaseContent 	= fileRead( '/coldbox-commands/templates/testing/Handler#stylePrefix#CaseContent#scriptPrefix#.txt' );

		// Start text replacements
		handlerTestContent 	= replaceNoCase( handlerTestContent, '|appMapping|', arguments.appMapping, 'all' );
		handlerTestContent 	= replaceNoCase( handlerTestContent, '|handlerName|', arguments.handler, 'all' );

		// Handle Actions if passed
		if( len( arguments.actions ) ) {
			var allActions 		= '';
			var allTestsCases 	= '';
			var thisTestCase 	= '';

			// Loop Over actions generating their functions
			for( var thisAction in listToArray( arguments.actions ) ) {
				thisAction = trim( thisAction );
				// genereate test case
				thisTestCase = replaceNoCase( handlerTestCaseContent, '|action|', thisAction, 'all' );
				thisTestCase = replaceNoCase( thisTestCase, '|event|', listChangeDelims( arguments.handler, '.', '/\' ) & '.' & thisAction, 'all' );
				allTestsCases &= thisTestCase & CR & CR;
			}

			// final replacements
			handlerTestContent = replaceNoCase( handlerTestContent, '|TestCases|', allTestsCases, 'all');
		} else {
			handlerTestContent 	= replaceNoCase( handlerTestContent, '|TestCases|', '', 'all' );
		}

		var integrationTestPath = '#arguments.directory#/#arguments.handler#Test.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( integrationTestPath ), true, true );

		// Confirm it
		if( fileExists( integrationTestPath ) && !confirm( "The file '#getFileFromPath( integrationTestPath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}

		// Write out the files
		file action='write' file='#integrationTestPath#' mode ='777' output='#handlerTestContent#';
		print.greenLine( 'Created #integrationTestPath#' );

		// open file
		if( arguments.open ){ openPath( integrationTestPath ); }
	}

}
/**
*  This will create a new controller (handler) in an existing ColdBox application.  Make sure you are running this command in the root
*  of your app for it to find the correct folder.  You can optionally create the views as well as the integration tests for your
*  new handler at the same time.  By default, your new controller will be created in /handlers but you can override that with the location param.    
*  
**/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="coldbox create handler" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the controller to create without the .cfc. For packages, specify name as "myPackage/myController"
	* @actions.hint A list of actions to generate, separated by a comma
	* @views.hint Generate a view for each action
	* @viewsDirectory.hint The directory where your views are stored. Only used if views is set to true.
	* @appMapping.hint The root location of the application in the web root: ex: /MyApp or / if in the root
	* @integrationTests.hint Generate the integration test component
	* @testsDirectory.hint Your integration tests directory. Only used if integrationTests is true
	* @directory.hint The base directory to create your handler in. 
	 **/
	function run( 	required name,
					actions='',
					boolean views=true,
					viewsDirectory='views',
					boolean integrationTest=true,
					appMapping='/',
					testsDirectory='/tests/specs/integration',
					directory='handlers' ) {
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
		viewsDirectory = fileSystemUtil.resolveDirectory( viewsDirectory );
		testsDirectory = fileSystemUtil.resolveDirectory( testsDirectory );
				
		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );			
		}
		
		// Allow dot-delimited paths
		name = replace( name, '.', '/', 'all' );
		var defaultDescription 	= 'I am a new handler';
		// This help readability so the success messages aren't up against the previous command line
		print.line();
				
		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		var script = true;
		if( script ) {
			scriptPrefix = 'Script';	
		}
		
		// Read in Templates
		var handlerContent = fileRead( '/commandbox/templates/HandlerContent#scriptPrefix#.txt' );
		var actionContent = fileRead( '/commandbox/templates/ActionContent#scriptPrefix#.txt' );
		var handlerTestContent = fileRead( '/commandbox/templates/testing/HandlerTestContent#scriptPrefix#.txt' );
		var handlerTestCaseContent = fileRead( '/commandbox/templates/testing/HandlerTestCaseContent#scriptPrefix#.txt' );
		
		
		// Start text replacements
		handlerContent = replaceNoCase( handlerContent, "|Name|", arguments.name, "all" );
		handlerTestContent = replaceNoCase( handlerTestContent, "|appMapping|", arguments.appMapping, "all" );
		
		// Placeholder in case we add this in
		arguments.Description = '';
		if( len(arguments.Description) ) {
			handlerContent = replaceNoCase( handlerContent, "|Description|", arguments.Description,"all");			
		} else {
			handlerContent = replaceNoCase( handlerContent, "|Description|", defaultDescription, "all" );			
		}
		
		// Handle Actions if passed
		if( len( arguments.actions ) ) {
			allActions = "";
			allTestsCases = "";
			thisTestCase = "";
			
			// Loop Over actions generating their functions
			for( var thisACtion in listToArray( arguments.actions ) ) {
				allActions = allActions & replaceNoCase( actionContent, "|action|", thisAction, "all" ) & chr(13) & chr(13);
				
				// Are we creating views?
				if( arguments.views ) {
					var viewPath = arguments.ViewsDirectory & '/' & arguments.name & '/' & thisAction & '.cfm'; 
					// Create dir if it doesn't exist					
					directorycreate( getDirectoryFromPath( viewPath ), true, true );
					// Create View Stub
					fileWrite( viewPath, '<cfoutput>#chr(13)#<h1>#arguments.name#.#thisAction#</h1>#chr(13)#</cfoutput>' );
					print.greenLine( 'Created ' & arguments.ViewsDirectory & '/' & arguments.name & '/' & thisAction & '.cfm' );
				}
				
				// Are we creating tests cases on actions
				if( arguments.integrationTest ) {
					thisTestCase = replaceNoCase( handlerTestCaseContent, "|action|", thisAction, "all" );
					thisTestCase = replaceNoCase( thisTestCase, "|event|", arguments.Name & "." & thisAction, "all" );
					allTestsCases = allTestsCases & thisTestCase & CR & CR;
				}
				
			}
			
			
			allActions = replaceNoCase( allActions, "|name|", arguments.Name, "all");
			handlerContent = replaceNoCase( handlerContent, "|EventActions|", allActions, "all");	
			handlerTestContent = replaceNoCase( handlerTestContent, "|TestCases|", allTestsCases, "all");	
		} else {
			handlerContent = replaceNoCase( handlerContent, "|EventActions|", '', "all" );
			handlerTestContent = replaceNoCase( handlerTestContent, "|TestCases|", '', "all" );	
		}
		
		var handlerPath = '#directory#/#name#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( handlerPath ), true, true );
		// Write out the files 
		file action='write' file='#handlerPath#' mode ='777' output='#handlerContent#';
		print.greenLine( 'Created #handlerPath#' );
		
		if( arguments.integrationTest ) {
			var testPath = '#arguments.TestsDirectory#/#name#Test.cfc';
			// Create dir if it doesn't exist
			directorycreate( getDirectoryFromPath( testPath ), true, true );
			// Create the tests
			file action='write' file='#testPath#' mode ='777' output='#handlerTestContent#';
			print.greenLine( 'Created #testPath#' );			
		}

		
	}

}
/**
* This will create a new interceptor in an existing ColdBox application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.  You can optionally create unit tests for your new interceptor at the same time.
* By default, your new interceptor will be created in /interceptors but you can override that with the directory param.
* Note, even though this command creates the interceptor CFC, you will still need to register it in the interceptors array
* in your ColdBox.cfc config file.
*
 **/
component extends='commandbox.system.BaseCommand' aliases='' excludeFromHelp=false {

	/**
	* @name.hint Name of the interceptor to create without the .cfc
	* @points.hint A comma-delimited list of interception points to generate
	* @tests.hint Generate the unit test component
	* @testsDirectory.hint Your unit tests directory. Only used if tests is true
	* @directory.hint The base directory to create your interceptor in
	 **/
	function run( required name,
					points='',
					boolean tests=true,
					testsDirectory='tests/specs/interceptors',
					directory='interceptors' ) {
		// This will make each directory canonical and absolute
		directory = fileSystemUtil.resolveDirectory( directory );
		testsDirectory = fileSystemUtil.resolveDirectory( testsDirectory );

		// Validate directory
		if( !directoryExists( directory ) ) {
			return error( 'The directory [#directory#] doesn''t exist.' );
		}

		// This help readability so the success messages aren't up against the previous command line
		print.line();

		// Script?
		var scriptPrefix = '';
		// TODO: Pull this from box.json
		var script = true;
		if( script ) {
			scriptPrefix = 'Script';
		}
		var defaultDescription 	= 'I am a new interceptor';

		// Read in Template
		var interceptorContent = fileRead( '/commandbox/templates/InterceptorContent#scriptPrefix#.txt' );
		var interceptorMethod = fileRead( '/commandbox/templates/InterceptorMethod#scriptPrefix#.txt' );
		var interceptorTestContent = fileRead( '/commandbox/templates/testing/InterceptorBDDContentScript.txt' );
		var interceptorTestCase = fileRead( '/commandbox/templates/testing/InterceptorBDDCaseContentScript.txt' );

		// Start Replacings
		interceptorContent = replaceNoCase( interceptorContent, '|Name|', name, 'all' );
		interceptorTestContent = replaceNoCase( interceptorTestContent, "|name|", name, "all" );

		// Placeholder in case we add this in
		Description = '';
		if( len(description) ) {
			interceptorContent = replaceNoCase( interceptorContent, '|Description|', description, 'all' );
		} else {
			interceptorContent = replaceNoCase( interceptorContent, '|Description|', defaultDescription, 'all' );
		}

		// Interception Points
		if( len( points ) ) {
			var methodContent = '';
			allTestsCases = '';
			thisTestCase = '';
			for( var thisPoint in listToArray( points ) ) {
				methodContent = methodContent & replaceNoCase( interceptorMethod, '|interceptionPoint|', thisPoint, 'all' ) & CR & CR;

				// Are we creating tests cases
				if( tests ) {
					thisTestCase = replaceNoCase( interceptorTestCase, '|point|', thisPoint, 'all' );
					allTestsCases &= thisTestCase & CR & CR;
				}

			}
			interceptorContent = replaceNoCase( interceptorContent, '|interceptionPoints|', methodContent, 'all' );
			interceptorTestContent = replaceNoCase( interceptorTestContent, '|TestCases|', allTestsCases, 'all');
		} else {
			interceptorContent = replaceNoCase( interceptorContent, '|interceptionPoints|', '', 'all' );
			interceptorTestContent = replaceNoCase( interceptorTestContent, '|TestCases|', '', 'all');
		}

		// Write it out.
		var interceptorPath = '#directory#/#name#.cfc';
		file action='write' file='#interceptorPath#' mode ='777' output='#interceptorContent#';
		print.greenLine( '#interceptorPath#' );

		if( tests ) {
			var testPath = '#TestsDirectory#/#name#Test.cfc';
			// Create dir if it doesn't exist
			directorycreate( getDirectoryFromPath( testPath ), true, true );
			// Create the tests
			file action='write' file='#testPath#' mode ='777' output='#interceptorTestContent#';
			print.greenLine( 'Created #testPath#' );
		}
	}

}
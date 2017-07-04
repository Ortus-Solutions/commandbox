/**
* Create a new view in an existing ColdBox application.  Run this command in the root
* of your app for it to find the correct folder.  By default, your new view will be created in /views but you can
* override that with the directory param.
* .
* {code:bash}
* coldbox create view myView
* {code}
*
**/
component {

	/**
	* @name.hint Name of the view to create without the .cfm.
	* @helper.hint Generate a helper file for this view
	* @directory.hint The base directory to create your view in and creates the directory if it does not exist.
	 **/
	function run(
		required name,
		boolean helper=false,
		directory='views'
	){
        // Allow dot-delimited paths
		arguments.name = replace( arguments.name, '.', '/', 'all' );

		// Check if the name is actually a path
		var nameArray = arguments.name.listToArray( '/' );
		var nameArrayLength = nameArray.len();
		if (nameArrayLength > 1) {
			// If it is a path, split the path from the name
			arguments.name = nameArray[nameArrayLength];
			var extendedPath = nameArray.slice(1, nameArrayLength - 1).toList('/');
			arguments.directory &= '/#extendedPath#';
		}

		// This will make each directory canonical and absolute
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// This help readability so the success messages aren't up against the previous command line
		print.line();

		var viewContent = '<h1>#arguments.name# view</h1>';
		var viewHelperContent = '<!--- #arguments.name# view Helper --->';

		// Write out view
		var viewPath = '#arguments.directory#/#arguments.name#.cfm';

		// Confirm it
		if( fileExists( viewPath ) && !confirm( "The file '#getFileFromPath( viewPath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}

		file action='write' file='#viewPath#' mode ='777' output='#viewContent#';
		print.greenLine( 'Created #viewPath#' );

		if( arguments.helper ) {
			// Write out view helper
			var viewHelperPath = '#arguments.directory#/#arguments.name#Helper.cfm';
			file action='write' file='#viewHelperPath#' mode ='777' output='#viewHelperContent#';
			print.greenLine( 'Created #viewHelperPath#' );

		}

	}

}
/**
 * Create a new layout in an existing ColdBox application.  Run this command in the root
 * of your app for it to find the correct folder.  By default, your new layout will be created in /layouts but you can
 * override that with the directory param.
 * .
 * {code:bash}
 * coldbox create layout myLayout
 * {code}
 *
 **/
component {

	/**
	 * @arguments.name Name of the layout to create without the .cfm.
	 * @helper Generate a helper file for this layout
	 * @directory The base directory to create your layout in and creates the directory if it does not exist.
	 **/
	function run(
		required name,
		boolean helper = false,
		directory      = "layouts"
	){
		// This will make each directory canonical and absolute
		arguments.directory = resolvePath( arguments.directory );

		// Validate directory
		if ( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// This help readability so the success messages aren't up against the previous command line
		print.line();

		var layoutContent       = "<h1>#arguments.name# Layout</h1>#CR#<cfoutput>##renderView()##</cfoutput>";
		var layoutHelperContent = "<!--- #arguments.name# Layout Helper --->";

		// Write out layout
		var layoutPath = "#arguments.directory#/#arguments.name#.cfm";

		// Confirm it
		if (
			fileExists( layoutPath ) && !confirm(
				"The file '#getFileFromPath( layoutPath )#' already exists, overwrite it (y/n)?"
			)
		) {
			print.redLine( "Exiting..." );
			return;
		}

		file action="write" file="#layoutPath#" mode="777" output="#layoutContent#";
		print.greenLine( "Created #layoutPath#" );

		if ( arguments.helper ) {
			// Write out layout helper
			var layoutHelperPath = "#arguments.directory#/#arguments.name#Helper.cfm";
			file action         ="write" file="#layoutHelperPath#" mode="777" output="#layoutHelperContent#";
			print.greenLine( "Created #layoutHelperPath#" );
		}
	}

}

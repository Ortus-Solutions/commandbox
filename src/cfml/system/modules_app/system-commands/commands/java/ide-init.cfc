/**
 * Writes editor metadata for the Java project so editors resolve the sources and
 * dependencies declared in the box.json java block.
 *
 * {code:bash}
 * java ide-init
 * java ide-init ide=vscode
 * java ide-init ide=vscode,intellij
 * {code}
 *
 * Editors in use are detected from the project, and each one gets its metadata
 * generated. On a project with no editor marker yet (a folder that was just
 * `java init`-ed, for example) it writes VS Code metadata rather than failing, so
 * the command always produces something useful. Pass `ide=` to target a specific
 * editor instead of detecting.
 *
 * Existing files are merged, so settings that are not ours are kept. Eclipse and
 * IntelliJ list the dependency JARs as they are at generation time, so re-run
 * this after installing dependencies.
 **/
component extends="commandbox.system.BaseCommand" {

	property name="javaIDEModel"   inject="JavaIDEModel";
	property name="javaIDEService" inject="JavaIDEService";

	/**
	 * @ide Force an editor instead of detecting: vscode, eclipse, intellij. Comma-delimited for several.
	 * @ide.options vscode,eclipse,intellij
	 */
	function run( string ide="" ) {
		var availableEditors = javaIDEService.availableEditors();

		for( var requestedId in listToArray( trim( arguments.ide ), ",", true ) ) {
			if( !availableEditors.findNoCase( trim( requestedId ) ) ) {
				error(
					message = "Unknown editor [#trim( requestedId )#].",
					detail  = "Valid editors are #availableEditors.toList( ', ' )#."
				);
			}
		}

		var model = javaIDEModel.build( getCWD() );

		var results = javaIDEService.write( model, arguments.ide );

		// A project with no editor marker yet is not a failure: default to VS Code so
		// `java init` followed by `java ide-init` produces working metadata.
		if( !results.len() && !len( trim( arguments.ide ) ) ) {
			print.yellowLine(
				"No editor detected in #model.projectRoot#. Writing VS Code metadata; pass ide=#availableEditors.toList( '|' )# to choose."
			);
			results = javaIDEService.write( model, "vscode" );
		}

		for( var result in results ) {
			print.line( "Wrote #result.ide#:" );
			for( var file in result.files ) {
				print.line( "    #file#" );
			}
		}
	}
}

/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I write VS Code Java settings into .vscode/settings.json and reference
* dependencies with a glob so a version bump needs no regeneration.
*
*/
component extends="BaseEmitter" {

	/**
	 * Detects whether this project already uses VS Code.
	 *
	 * @root The project root.
	 * @returns True when a `.vscode` folder or a workspace file is present.
	 */
	boolean function detect( required string root ) {
		return directoryExists( arguments.root & "/.vscode" )
			|| directoryList( arguments.root, false, "path", "*.code-workspace" ).len() > 0;
	}

	/**
	 * Describes the VS Code files to write from the project model.
	 *
	 * @model The editor-neutral project model.
	 * @returns The file specifications.
	 */
	array function files( required struct model ) {
		var libraries = [];
		for( var entry in arguments.model.classPath ) {
			var library = relative( entry.path, arguments.model );
			libraries.append( entry.kind == "directory" ? library & "/**/*.jar" : library );
		}
		// Test-only dependencies are editor libraries too, so the gutter test runner
		// can resolve JUnit without the project mixing them into the runtime set.
		for( var entry in arguments.model.testClassPath ) {
			var library = relative( entry.path, arguments.model );
			libraries.append( entry.kind == "directory" ? library & "/**/*.jar" : library );
		}
		var model = arguments.model;
		var sourceRoots = duplicate( model.sourceRoots );
		for( var testRoot in model.testSourceRoots ) {
			if( !sourceRoots.find( testRoot ) ) sourceRoots.append( testRoot );
		}
		var patches = [
			patch( "java.project.sourcePaths", [ sourceRoots.map( function( root ) {
				return relative( root, model );
			} ) ] ),
			patch( "java.project.outputPath", [ relative( model.outputDirectory, model ) ] ),
			patch( "java.project.referencedLibraries", [ { "include" : libraries } ] )
		];
		return [ { "path" : ".vscode/settings.json", "format" : "json", "seed" : "{}", "patches" : patches } ];
	}
}

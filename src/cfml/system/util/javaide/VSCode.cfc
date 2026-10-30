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

	boolean function detect( required string root ) {
		return directoryExists( arguments.root & "/.vscode" )
			|| directoryList( arguments.root, false, "path", "*.code-workspace" ).len() > 0;
	}

	array function files( required struct model ) {
		var libraries = [];
		for( var entry in arguments.model.classPath ) {
			var library = relative( entry.path, arguments.model );
			libraries.append( entry.kind == "directory" ? library & "/**/*.jar" : library );
		}
		var model = arguments.model;
		var patches = [
			patch( "java.project.sourcePaths", [ model.sourceRoots.map( function( root ) {
				return relative( root, model );
			} ) ] ),
			patch( "java.project.outputPath", [ relative( model.outputDirectory, model ) ] ),
			patch( "java.project.referencedLibraries", [ libraries ] )
		];
		return [ { "path" : ".vscode/settings.json", "format" : "json", "seed" : "{}", "patches" : patches } ];
	}
}

/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I find which editors are in use in a project and have each one write its
* metadata from the editor-neutral Java project model. An editor emitter
* implements detect( root ) and files( model ).
*
*/
component singleton {

	property name="wirebox"        inject="wirebox";
	property name="fileSystemUtil" inject="FileSystem";
	property name="documents"      inject="JavaIDEDocuments";

	function init() {
		variables.emitters = structNew( "ordered" );
		register( "vscode", "commandbox.system.util.javaide.VSCode" );
		register( "eclipse", "commandbox.system.util.javaide.Eclipse" );
		register( "intellij", "commandbox.system.util.javaide.IntelliJ" );
		return this;
	}

	/**
	 * Adds an emitter so a new editor is a new class, not a change to the command.
	 * Accepts a CFC path or an already constructed emitter.
	 *
	 * @id Emitter id used in messages.
	 * @emitter Emitter CFC path or instance.
	 */
	function register( required string id, required any emitter ) {
		variables.emitters[ arguments.id ] = arguments.emitter;
		return this;
	}

	/**
	 * Writes the metadata for every editor detected in the project.
	 *
	 * @model The editor-neutral project model.
	 * @returns Array of structs with the editor id and the files written.
	 */
	array function write( required struct model ) {
		var results = [];
		for( var id in variables.emitters ) {
			if( !emitter( id ).detect( arguments.model.projectRoot ) ) {
				continue;
			}
			var written = [];
			for( var specification in emitter( id ).files( arguments.model ) ) {
				var target = fileSystemUtil.resolvePath( specification.path, arguments.model.projectRoot );
				// Editors own these files too; never replace one the user already has.
				if( ( specification.createOnly ?: false ) && fileExists( target ) ) {
					continue;
				}
				var exists = fileExists( target );
				var parent = getDirectoryFromPath( target );
				if( !directoryExists( parent ) ) {
					directoryCreate( parent, true );
				}
				fileWrite(
					target,
					documents.render(
						specification,
						exists ? fileRead( target ) : "",
						exists
					),
					"utf-8"
				);
				written.append( specification.path );
			}
			results.append( { "ide" : id, "files" : written } );
		}
		if( !results.len() ) {
			throw(
				type="commandException",
				message="No editor metadata detected in #arguments.model.projectRoot#.",
				detail="java ide-init writes metadata for VS Code (.vscode), Eclipse (.project/.classpath) and IntelliJ (.idea or an .iml)."
			);
		}
		return results;
	}

	private any function emitter( required string id ) {
		var registered = variables.emitters[ arguments.id ];
		return isSimpleValue( registered ) ? wirebox.getInstance( registered ) : registered;
	}
}

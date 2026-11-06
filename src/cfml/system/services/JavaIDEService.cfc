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
	property name="jsonService"    inject="JSONService";

	/**
	 * Registers the built-in editor emitters. A new editor is a new class plus a
	 * registration here, never a change to the command.
	 *
	 * @returns The service instance.
	 */
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
	 * Writes the metadata for every editor detected in the project, or for the
	 * editors the caller names.
	 *
	 * Detecting nothing is not an error: an empty project simply has no editor
	 * marker yet, so an empty result is returned and the caller decides what to do.
	 *
	 * @model The editor-neutral project model.
	 * @ide Comma-delimited editor ids to force. Empty means "detect".
	 * @returns Array of structs with the editor id and the files written.
	 */
	array function write( required struct model, string ide="" ) {
		// Unknown ids are validated by the command; anything left here is a real editor.
		var ids = requestedEditors( arguments.ide );

		if( !ids.len() && !len( trim( arguments.ide ) ) ) {
			ids = detectedEditors( arguments.model.projectRoot );
		}

		var results = [];
		for( var id in ids ) {
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
				var document = documents.apply(
					specification,
					exists ? fileRead( target ) : "",
					exists
				);
				// JSONService owns JSON formatting (JSON.indent, key sorting, line endings),
				// so editor settings are written the same way box.json is.
				if( specification.format == "json" ) {
					jsonService.writeJSONFile( target, document );
				} else {
					fileWrite( target, documents.stringify( specification.format, document ), "utf-8" );
				}
				written.append( specification.path );
			}
			results.append( { "ide" : id, "files" : written } );
		}
		return results;
	}

	/**
	 * Returns the ids of the emitters whose editor is in use in this project.
	 *
	 * @root The project root to inspect.
	 */
	array function detectedEditors( required string root ) {
		var detected = [];
		for( var id in variables.emitters ) {
			if( emitter( id ).detect( arguments.root ) ) {
				detected.append( id );
			}
		}
		return detected;
	}

	/**
	 * Returns the ids of every registered emitter.
	 */
	array function availableEditors() {
		return variables.emitters.keyArray();
	}

	/**
	 * Normalizes the caller's editor ids.
	 *
	 * @ide Comma-delimited editor ids, or an empty string.
	 */
	private array function requestedEditors( required string ide ) {
		if ( !len( trim( arguments.ide ) ) ) {
			return [];
		}

		var ids = [];
		for ( var id in arguments.ide.listToArray( "," ) ) {
			if ( len( trim( id ) ) && !ids.findNoCase( trim( id ) ) ) {
				ids.append( lCase( trim( id ) ) );
			}
		}
		return ids;
	}

	/**
	 * Resolves a registered emitter, which may still be a CFC path.
	 *
	 * @id The emitter id.
	 * @returns The emitter instance.
	 */
	private any function emitter( required string id ) {
		var registered = variables.emitters[ arguments.id ];
		return isSimpleValue( registered ) ? wirebox.getInstance( registered ) : registered;
	}
}

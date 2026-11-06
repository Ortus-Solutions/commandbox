/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I am the shared base for the IDE emitters. I only help turn absolute model paths
* into project-relative editor paths and build patch descriptions.
*
*/
component {

	/**
	 * Turns an absolute model path into a project-relative editor path.
	 *
	 * @path The absolute path to make relative.
	 * @model The editor-neutral project model.
	 * @returns The path relative to the project root, or the original path when it is outside it.
	 */
	string function relative( required string path, required struct model ) {
		var root = arguments.model.projectRoot & "/";
		if( arguments.path == arguments.model.projectRoot ) return ".";
		return arguments.path.startsWith( root ) ? arguments.path.right( -len( root ) ) : arguments.path;
	}

	/**
	 * Escapes a value for use in XML content and attributes.
	 *
	 * @value The value to escape.
	 * @returns The XML-safe value.
	 */
	string function escape( required string value ) {
		return xmlFormat( arguments.value );
	}

	/**
	 * Describes one patch to apply to an editor file.
	 *
	 * @key The format-specific selector identifying what to replace.
	 * @value The XML fragments (or JSON value) to write in its place.
	 * @parent The selector of the parent node, for XML formats.
	 * @returns The patch description.
	 */
	struct function patch( required string key, required array value, string parent="" ) {
		return { "key" : arguments.key, "value" : arguments.value, "parent" : arguments.parent };
	}

	/**
	 * Describes a container element that must exist before its children are patched.
	 *
	 * @key The selector identifying the container.
	 * @parent The selector of the container's parent.
	 * @xml The XML fragment for the container.
	 * @returns The container description.
	 */
	struct function container( required string key, required string parent, required string xml ) {
		return { "key" : arguments.key, "parent" : arguments.parent, "xml" : arguments.xml };
	}

	/**
	 * XPath literals must support project paths containing either quote character.
	 */
	string function literal( required string value ) {
		if( !find( "'", arguments.value ) ) return "'" & arguments.value & "'";
		if( !find( '"', arguments.value ) ) return '"' & arguments.value & '"';
		var parts = listToArray( arguments.value, "'", true );
		return "concat('" & parts.toList( "'," & '"''"' & ",'" ) & "')";
	}
}

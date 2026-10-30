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

	string function relative( required string path, required struct model ) {
		var root = arguments.model.projectRoot & "/";
		if( arguments.path == arguments.model.projectRoot ) return ".";
		return arguments.path.startsWith( root ) ? arguments.path.right( -len( root ) ) : arguments.path;
	}

	string function escape( required string value ) {
		return xmlFormat( arguments.value );
	}

	struct function patch( required string key, required array value, string parent="" ) {
		return { "key" : arguments.key, "value" : arguments.value, "parent" : arguments.parent };
	}

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

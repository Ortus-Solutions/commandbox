/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* I apply generated IDE metadata into files the editor also owns, so keys and
* entries that belong to the user are left alone. Applying is idempotent:
* running twice produces the same file.
*
*/
component {

	/**
	 * Applies a specification's patches and returns the resulting document.
	 *
	 * JSON comes back as a struct so the caller can hand it to JSONService, which owns
	 * pretty printing and the JSON.* settings. XML comes back as a DOM, and any other
	 * format as a string.
	 *
	 * @specification A struct describing the file, its format, and the patches to apply.
	 * @current The existing file content, or an empty string when the file is new.
	 * @exists Whether the file already exists.
	 */
	any function apply( required struct specification, required string current, required boolean exists ) {
		var spec = arguments.specification;
		var document = parseDocument( spec.format, arguments.exists ? arguments.current : spec.seed );
		for( var container in ( spec.containers ?: [] ) ) {
			if( !nodes( document, container.key ).getLength() ) {
				writeXML( document, container.key, [ container.xml ], container.parent );
			}
		}
		for( var patch in spec.patches ) {
			document = writeValue( spec.format, document, patch.key, patch.value, patch.parent ?: "" );
		}
		return document;
	}

	/**
	 * Parses existing file content into the working document for its format.
	 *
	 * XML is parsed with external entities and doctypes disabled, since the file is
	 * editor-owned content that we only merge into.
	 *
	 * @format The file format: json, xml, properties, or text.
	 * @content The current file content, or the format's seed content.
	 * @returns A struct for JSON, a DOM for XML, or the content itself for other formats.
	 */
	private any function parseDocument( required string format, required string content ) {
		if( arguments.format == "json" ) {
			var result = deserializeJSON( arguments.content );
			if( !isStruct( result ) ) {
				throw( type="commandException", message="Editor settings must be a JSON object." );
			}
			return result;
		}
		if( arguments.format != "xml" ) {
			return arguments.content;
		}
		var factory = xmlClass( "javax.xml.parsers.DocumentBuilderFactory" )
			.getMethod( "newInstance", [] ).invoke( javaCast( "null", "" ), [] );
		factory.setFeature( "http://apache.org/xml/features/disallow-doctype-decl", true );
		factory.setFeature( "http://xml.org/sax/features/external-general-entities", false );
		factory.setFeature( "http://xml.org/sax/features/external-parameter-entities", false );
		var source = createObject( "java", "java.io.ByteArrayInputStream" ).init(
			charsetDecode( arguments.content, "utf-8" )
		);
		return factory.newDocumentBuilder().parse( source );
	}

	/**
	 * Serializes a document from apply() for the formats that are not written by JSONService.
	 *
	 * @format The file format.
	 * @document The document to serialize.
	 */
	string function stringify( required string format, required any document ) {
		if( arguments.format != "xml" ) {
			return arguments.document;
		}
		var factory = xmlClass( "javax.xml.transform.TransformerFactory" )
			.getMethod( "newInstance", [] ).invoke( javaCast( "null", "" ), [] );
		var transformer = factory.newTransformer();
		transformer.setOutputProperty( "omit-xml-declaration", "yes" );
		var writer = createObject( "java", "java.io.StringWriter" ).init();
		transformer.transform(
			xmlClass( "javax.xml.transform.dom.DOMSource" )
				.getConstructor( [ xmlClass( "org.w3c.dom.Node" ) ] ).newInstance( [ arguments.document ] ),
			xmlClass( "javax.xml.transform.stream.StreamResult" )
				.getConstructor( [ xmlClass( "java.io.Writer" ) ] ).newInstance( [ writer ] )
		);
		return writer.toString();
	}

	/**
	 * Evaluates an XPath expression against a document.
	 *
	 * @document The DOM to query.
	 * @selector The XPath expression.
	 * @returns The matching node set.
	 */
	private any function nodes( required any document, required string selector ) {
		var factory = xmlClass( "javax.xml.xpath.XPathFactory" )
			.getMethod( "newInstance", [] ).invoke( javaCast( "null", "" ), [] );
		return factory.newXPath().evaluate(
			arguments.selector,
			arguments.document,
			xmlClass( "javax.xml.xpath.XPathConstants" ).getField( "NODESET" ).get( javaCast( "null", "" ) )
		);
	}

	/**
	 * Applies one patch to the document, per format.
	 *
	 * JSON keys are replaced wholesale, XML nodes are re-written, and properties files
	 * have the matching key replaced while everything else is preserved.
	 *
	 * @format The file format.
	 * @document The working document.
	 * @key The format-specific selector or property name.
	 * @value The values to write.
	 * @parent The parent selector, for XML formats.
	 * @returns The updated document.
	 */
	private any function writeValue(
		required string format, required any document, required string key,
		required array value, required string parent
	) {
		if( arguments.format == "json" ) {
			structDelete( arguments.document, arguments.key );
			if( arguments.value.len() ) {
				arguments.document[ arguments.key ] = arguments.value[ 1 ];
			}
		} else if( arguments.format == "xml" ) {
			writeXML( arguments.document, arguments.key, arguments.value, arguments.parent );
		} else if( arguments.format == "properties" ) {
			// Drop blank lines so a trailing newline does not accumulate on each run.
			var lines = listToArray( arguments.document, chr( 10 ), true ).filter( function( line ) {
				return len( trim( line ) ) && propertyKey( line ) != key;
			} );
			lines.append( arguments.value, true );
			return lines.len() ? lines.toList( chr( 10 ) ) & chr( 10 ) : "";
		} else {
			return arguments.value.len() ? arguments.value[ 1 ] : "";
		}
		return arguments.document;
	}

	/**
	 * Reads the property name out of one properties-file line.
	 *
	 * @line The line to inspect.
	 * @returns The trimmed property name.
	 */
	private string function propertyKey( required string line ) {
		return trim( listFirst( reReplace( arguments.line, "[=:]", chr( 9 ), "one" ), chr( 9 ) ) );
	}

	/**
	 * Replaces any matching nodes with the supplied XML, creating the parent when needed.
	 */
	private void function writeXML(
		required any document, required string selector, required array values, required string parent
	) {
		if( reFind( "/@[A-Za-z_][A-Za-z0-9_.-]*$", arguments.selector ) ) {
			var owners = nodes( arguments.document, arguments.parent );
			if( owners.getLength() != 1 ) {
				throw( type="commandException", message="Expected one XML metadata parent: #arguments.parent#" );
			}
			var attribute = listLast( arguments.selector, "@" );
			owners.item( 0 ).removeAttribute( attribute );
			if( arguments.values.len() ) {
				owners.item( 0 ).setAttribute( attribute, arguments.values[ 1 ] );
			}
			return;
		}
		var selected = nodes( arguments.document, arguments.selector );
		for( var index = selected.getLength() - 1; index >= 0; index-- ) {
			var node = selected.item( javaCast( "int", index ) );
			node.getParentNode().removeChild( node );
		}
		if( !arguments.values.len() ) {
			return;
		}
		var parents = nodes( arguments.document, arguments.parent );
		if( parents.getLength() != 1 ) {
			throw( type="commandException", message="Expected one XML metadata parent: #arguments.parent#" );
		}
		for( var value in arguments.values ) {
			var fragment = parseDocument( "xml", value );
			parents.item( 0 ).appendChild( arguments.document.importNode( fragment.getDocumentElement(), true ) );
		}
	}

	/**
	 * Use the JDK's XML classes, not older copies bundled by optional modules.
	 */
	private any function xmlClass( required string name ) {
		return createObject( "java", "java.lang.Class" ).forName( arguments.name, true, javaCast( "null", "" ) );
	}
}

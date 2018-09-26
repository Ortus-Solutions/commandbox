component {
    public any function init() {
        var osName = createObject( 'java', 'java.lang.System' ).getProperty( 'os.name' );
        variables.defaultLineEnding = osName.findNoCase( 'windows' ) ? chr( 13 ) & chr( 10 ) : chr( 10 );
        variables.defaultIndent = '    ';
        return this;
    }

    /**
     * Pretty JSON
     * @json A string containing JSON, or a complex value that can be serialized to JSON
     * @indent String to use for indenting lines.  Defaults to four spaces.
     * @lineEnding String to use for line endings.  Defaults to CRLF on Windows and LF on *nix
     * @spaceAfterColon Add space after each colon like "value": true instead of"value":true
     * @sortKeys Specify a sort type to sort the keys of json objects: "text" or "textnocase"
     **/
    public string function formatJson(
        required any json,
        string indent = defaultIndent,
        string lineEnding = defaultLineEnding,
        boolean spaceAfterColon = false,
        string sortKeys = ''
    ) {
        if ( isSimpleValue( json ) ) {
            json = deserializeJSON( json );
        }
        var settings = {
            indent: indent,
            lineEnding: lineEnding,
            colon: spaceAfterColon ? ': ' : ':',
            sortKeys: sortKeys
        };
        return printString( json, settings );
    }

    private string function printString( json, settings, baseIndent = '' ) {
        if ( isStruct( json ) ) {
            if ( structIsEmpty( json ) ) {
                return '{}';
            }
            var keys = json.keyArray();
            if ( len( settings.sortKeys ) ) {
                keys.sort( settings.sortKeys );
            }
            var strs = [ ];
            for ( var key in keys ) {
                var str = baseIndent & settings.indent & '"#key#"' & settings.colon;
                if ( !structKeyExists( json, key ) || isNull( json[ key ] ) ) {
                    str &= 'null';
                } else {
                    str &= printString( json[ key ], settings, baseIndent & settings.indent );
                }
                strs.append( str );
            }
            return '{' & settings.lineEnding & strs.toList( ',' & settings.lineEnding ) & settings.lineEnding & baseIndent & '}';
        }
        if ( isArray( json ) ) {
            if ( arrayIsEmpty( json ) ) {
                return '[]';
            }
            var strs = [ ];
            for ( var item in json ) {
                var str = baseIndent & settings.indent;
                if ( isNull( item ) ) {
                    str &= 'null';
                } else {
                    str &= printString( item, settings, baseIndent & settings.indent );
                }
                strs.append( str );
            }
            return '[' & settings.lineEnding & strs.toList( ',' & settings.lineEnding ) & settings.lineEnding & baseIndent & ']';
        }
        // This could be a query, a Java object like a HashMap, or an XML Doc.
        // Before giving up, we'll give the CF engine a chance to turn it into something useful.
        if( !isSimpleValue( json ) ) {
        	// Attempt to convert to native JSON data types...
        	arguments.json = deserializeJSON( serializeJSON( json ) );
            // ensure we have something that we can work with
            if ( !isStruct( json ) && !isArray( json ) && !isSimpleValue( json ) ) {
                throw( 'Sorry, we can''t convert an object of type [#json.getClass().getName()#] to JSON.' );
            }
        	// ... and start over.
        	return printString( argumentCollection=arguments );
        }
        /*
            Simple types don't require any special formatting so we can let
            serializeJSON convert them to JSON for us.
        */
        return serializeJSON( json );
    }
}

/**
*********************************************************************************
* Copyright Since 2014 by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
*/
component accessors="true" singleton alias='JSONPrettyPrint' {

    property name="CFMLPrinter" inject="CFMLPrinter@JSONPrettyPrint";
    property name="JSONPrinter" inject="JSONPrinter@JSONPrettyPrint";

    property name="DefaultPrinter" type="string";

    function init() {
        if ( server.coldfusion.productname == 'Lucee' && listFirst( server.lucee.version, '.' ) >= 5 ) {
            setDefaultPrinter( 'CFMLPrinter' );
        } else {
            setDefaultPrinter( 'JSONPrinter' );
        }
        variables.os = createObject( 'java', 'java.lang.System' ).getProperty( 'os.name' ).toLowerCase();
        return this;
    }

    // OS detector
    private boolean function isWindows() {
        return variables.os.contains( 'win' );
    }

    /**
     * Pretty JSON
     * @json A string containing JSON, or a complex value that can be serialized to JSON
     * @indent String to use for indenting lines.  Defaults to four spaces.
     * @lineEnding String to use for line endings.  Defaults to CRLF on Windows and LF on *nix
     * @spaceAfterColon Add space after each colon like "value": true instead of"value":true
     * @sortKeys Specify a sort type to sort the keys of json objects: "text" or "textnocase"
     * @ansiColors A struct of ANSI color codes. If supplied, output will be ANSI encoded. Struct keys are "constant", "key", "number", and "string" and values are valid ANSI escape sequence such as chr( 27 ) & '[38;5;52m'.
     **/
    public function formatJson(
        any json,
        string indent = '    ',
        lineEnding,
        boolean spaceAfterColon = false,
        string sortKeys = '',
        struct ansiColors = {}
    ) {
        // Default line ending based on OS
        if ( isNull( arguments.lineEnding ) ) {
            if ( isWindows() ) {
                arguments.lineEnding = chr( 13 ) & chr( 10 );
            } else {
                arguments.lineEnding = chr( 10 );
            }
        }

        return variables[ getDefaultPrinter() ].formatJson( argumentCollection = arguments );
    }

}

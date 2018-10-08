component accessors="true" {

    property ANSIDefaults;

    function init() {
        setANSIDefaults( {
            constant: 0,
            key: 0,
            number: 0,
            string: 0
        } );
        return this;
    }

    function wrap( str, type, colors ) {
        var code = 0;

        if ( type == 'key' ) {
            code = colors.key;
        } else if ( left( str, 1 ) == '"' ) {
            code = colors.string;
        } else if ( len( str ) > 3 && arrayFind( [ 'true', 'false', 'null' ], str ) ) {
            code = colors.constant;
        } else {
            code = colors.number;
        }

        if ( code ) {
            return ANSIColor( code ) & str & ANSIReset();
        }
        return str;
    }

    private function ANSIColor( code ) {
        return chr( 27 ) & '[38;5;' & code & 'm';
    }

    private function ANSIReset() {
        return chr( 27 ) & '[0m';
    }

}

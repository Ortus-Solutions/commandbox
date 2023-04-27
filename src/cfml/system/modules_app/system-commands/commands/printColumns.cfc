/**
 * Prints a list or array of information as columns
 *
 * JSON or list data can be passed in the first param or piped into the command:
 * {code:bash}
 * printColumns [1,2,3]
 * ls --simple | printColumns
 * {code}
 */
component {

	/**
     * Outputs a list of items in column form
	 * @data JSON serialized array or list
	 * @delimiter List delimiter (default to new line)
     */

    public string function run(
		String data='',
        String delimiter=chr(13)&chr(10)
    ) {

		data = print.unAnsi( data );

		//deserialize data if in a JSON format
		if( isJSON( data) ) {
			data = deserializeJSON( data );
			if( isSimpleValue( data ) ) {
				data = [ data ];
			} else if( !isArray( data ) ) {
				error( 'Only JSON arrays can be used with the printColumn command' );
			}
		} else {
			data = data.listToArray( delimiter );
		}

		print.columns( data );
	}

}

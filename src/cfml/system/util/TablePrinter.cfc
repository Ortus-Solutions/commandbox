component singleton {

    property name="print" inject="PrintBuffer";

    variables.tableChars = {
		"top": chr( 9552 ), // ═
		"topMid": chr( 9572 ), // ╤
		"topLeft": chr( 9556 ), // ╔
		"topRight": chr( 9559 ), // ╗
		"bottom": chr( 9552 ), // ═
		"bottomMid": chr( 9575 ), // ╧
		"bottomLeft": chr( 9562 ), // ╚
		"bottomRight": chr( 9565 ), // ╝
		"left": chr( 9553 ), // ║
		"leftMid": chr( 9567 ), // ╟
		"mid": chr( 9472 ), // ─
		"midMid": chr( 9532 ), // ┼
		"right": chr( 9553 ), // ║
		"rightMid": chr( 9570 ), // ╢
		"middle": chr( 9474 ) // │
	};

    /**
     * Outputs a table to the screen
     * @headers.hint An array of column headers.
     * @data.hint An array of data for the table.  Each item in the array may either be
     *            an array in the correct order matching the number of headers or a struct
     *            with keys matching the headers.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
    public void function print(
        required array headers,
        required array data
    ) {
        processingdirective pageEncoding='UTF-8';
		arguments.data = autoFormatData( arguments.data, arguments.headers );
		var headerData = arguments.headers.map( ( header, index ) => {
			return {
				"value": header,
				"maxWidth": calculateMaxColumnWidth( index, header, data )
			};
		} );
		printHeader( headerData );
		printData( data, headerData );
		printTableEnd( headerData );
        print.toConsole();
	}

    /**
     * Prints the header row for the table.
     * @headerData.hint The array of column headers for the table with their corresponding max widths.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
	private void function printHeader( required array headerData ) {
		// top bar
		print.green( variables.tableChars.topLeft );
		arguments.headerData.each( ( header, index ) => {
			print.green( variables.tableChars.top );
			for ( var i = 1; i <= header.maxWidth; i++ ) {
				print.green( variables.tableChars.top );
			}
			print.green( variables.tableChars.top );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.topMid );
			} else {
				print.greenLine( variables.tableChars.topRight );
			}
		} );

		// headers
		print.green( variables.tableChars.left );
		arguments.headerData.each( ( header, index ) => {
			print.white( " " );
			print.boldWhite( padRight( header.value, header.maxWidth ) );
			print.white( " " );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.middle );
			} else {
				print.greenLine( variables.tableChars.right );
			}
		} );

		// bottom bar
		print.green( variables.tableChars.leftMid );
		arguments.headerData.each( ( header, index ) => {
			print.green( variables.tableChars.top );
			for ( var i = 1; i <= header.maxWidth; i++ ) {
				print.green( variables.tableChars.top );
			}
			print.green( variables.tableChars.top );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.midMid );
			} else {
				print.greenLine( variables.tableChars.rightMid );
			}
		} );
	}

    /**
     * Prints all the data for the table.
     * @data.hint The data for the table.
     * @headerData.hint The array of column headers for the table with their corresponding max widths.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
	private void function printData( required array data, required array headerData ) {
		arguments.data.each( ( row, index ) => {
			printRow( row, headerData );
			if ( index != data.len() ) {
				printRowSeparator( headerData );
			}
		} );
	}

    /**
     * Prints a single row of data for the table.
     * @row.hint A signle row of data for the table.
     * @headerData.hint The array of column headers for the table with their corresponding max widths.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
	private void function printRow( required array row, required array headerData ) {
		print.green( variables.tableChars.left );
		arguments.headerData.each( ( header, index ) => {
			print.white( " " );
			var data = row[ index ];
			var options = "white";
			if ( isStruct( data ) ) {
				options = data.options;
				data = data.value;
			}
			print.text( padRight( data, header.maxWidth ), options );
			print.white( " " );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.middle );
			} else {
				print.greenLine( variables.tableChars.right );
			}
		} );
	}

    /**
     * Prints the separator between rows.
     * @headerData.hint The array of column headers for the table with their corresponding max widths.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
	private void function printRowSeparator( required array headerData ) {
		print.green( variables.tableChars.leftMid );
		arguments.headerData.each( ( header, index ) => {
			print.green( variables.tableChars.mid );
			for ( var i = 1; i <= header.maxWidth; i++ ) {
				print.green( variables.tableChars.mid );
			}
			print.green( variables.tableChars.mid );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.midMid );
			} else {
				print.greenLine( variables.tableChars.rightMid );
			}
		} );
	}

    /**
     * Prints the final line of the table.
     * @headerData.hint The array of column headers for the table with their corresponding max widths.
     * @print.hint A reference to the CommandBox Printer that called this table printer.
     */
	private void function printTableEnd( required array headerData ) {
		print.green( variables.tableChars.bottomLeft );
		arguments.headerData.each( ( header, index ) => {
			print.green( variables.tableChars.bottom );
			for ( var i = 1; i <= header.maxWidth; i++ ) {
				print.green( variables.tableChars.bottom );
			}
			print.green( variables.tableChars.bottom );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.bottomMid );
			} else {
				print.greenLine( variables.tableChars.bottomRight );
			}
		} );
	}

    /**
     * Formats the data into an array of arrays.
     * If the data is an array of structs, the headers will be used to convert it to an array of arrays.
     * @data.hint The data for the table.
     * @headers.hint The column headers for the table.  Used as the lookup keys if data is an array of structs.
     */
	private array function autoFormatData( required array data, required array headers ) {
		if ( arguments.data.isEmpty() ) {
			return [];
		}

		return arguments.data.map( ( item ) => {
			if ( isArray( item ) ) {
				return item;
			}
			return getStructValues( item, headers );
		} );
	}

    /**
     * Gets the required keys from the struct of data and returns them as an array of arrays.
     * @item.hint The struct of data representing a single row.
     * @headers.hint The column headers for the table used to get the needed data from the item in the correct order.
     */
	private array function getStructValues( required struct item, required array headers ) {
		return arguments.headers.map( ( key ) => {
			return item[ key ];
		} );
	}

    /**
     * Calculates the max width of a column across the header and all rows of data.
     * This value is used to layout the table correctly.
     * @index.hint The index of the column we are calculating.
     * @header.hint The column header.
     * @data.hint The data for the table.
     */
	private numeric function calculateMaxColumnWidth( required numeric index, required string header, required array data ) {
		return arguments.data.reduce( ( acc, row ) => {
			var data = row[ index ];
			if ( isStruct( data ) ) {
				data = data.value;
			}
			return max( acc, len( data ) );
		}, len( arguments.header ) );
	}

    /**
     * Adds characters to the right of a string until the string reaches a certain length.
     * If the text is already greater than or equal to the maxWidth, the text is returned unchanged.
     * @text.hint The text to pad.
     * @maxWidth.hint The number of characters to pad up to.
     * @padChar.hint The character to use to pad the text.
     */
	private string function padRight( required string text, required numeric maxWidth, string padChar = " " ) {
		var textLength = len( arguments.text );
		if ( textLength >= arguments.maxWidth ) {
			return arguments.text;
		}

		for ( var i = textLength; i < arguments.maxWidth; i ++ ) {
			arguments.text &= arguments.padChar;
		}

		return arguments.text;
	}

}
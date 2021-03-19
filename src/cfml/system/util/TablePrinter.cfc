component singleton {

    processingdirective pageEncoding='UTF-8';
    
    property name="print" inject="PrintBuffer";
    property name="shell" inject="shell";

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
		"headerLeftMid": chr( 9568 ), // ╠
		"mid": chr( 9472 ), // ─
		"midMid": chr( 9532 ), // ┼
		"headerMidMid": chr( 9578 ), // ╪
		"right": chr( 9553 ), // ║
		"rightMid": chr( 9570 ), // ╢
		"headerRightMid": chr( 9571 ), // ╣
		"middle": chr( 9474 ) // │
	};
	

    /**
     * Outputs a table to the screen
     * @headers An array of column headers, or a query.  When passing a query, the "data" argument is not used.
     * @data An array of data for the table.  Each item in the array may either be
     *            an array in the correct order matching the number of headers or a struct
     *            with keys matching the headers.
     */
    public void function print(
        required any headers,
        array data=[]
    ) {
    	// If query is sent in
    	if( isQuery( arguments.headers ) ) {
    		// Extract data in array of structs
    		arguments.data = arguments.headers.reduce( (acc,row)=>{ return acc.append( row ) }, [] );
    		// Extract column names into headers
    		arguments.headers = arguments.headers.columnList.listToArray();
    	}
    	
		arguments.data = autoFormatData( arguments.headers,arguments.data );
		var headerData = processHeaders( arguments.headers, arguments.data )
		
		printHeader( headerData );
		printData( data, headerData );
		printTableEnd( headerData );
        print.toConsole();
	}

    /**
     * Outputs a table to the screen
     * @headers An array of column headers,
     * @data An array of data for the table.
     */
    public array function processHeaders(
        required array headers,
        required array data
    ) {
        var headerData = arguments.headers.map( ( header, index ) => calculateColumnData( index, header, data ) );
        var termWidth = shell.getTermWidth()-3;
        var tableWidth = headerData.reduce( (acc=0,header)=>acc+header.maxWidth+3 )+1;
        // Crunch time
        if( tableWidth > termWidth ) {
        	var overage = tableWidth-termWidth;
        	var medianRatioTotal = headerData.reduce( (acc=0,header)=>acc+( header.medianRatio ) );
        	
        	for( var header in headerData ) {
        		var charsToLose = round( overage*( header.medianRatio/medianRatioTotal ) );
        		header.maxWidth=max( header.maxWidth-charsToLose, 3 );
        	}
        }
        
        return headerData;
	}

    /**
     * Calculates the max width of a column across the header and all rows of data.
     * This value is used to layout the table correctly.
     * @index The index of the column we are calculating.
     * @header The column header.
     * @data The data for the table.
     */
	private struct function calculateColumnData( required numeric index, required string header, required array data ) {
		var colData = arguments.data.reduce( ( acc, row, rowIndex ) => {
			if( row.len() < index ) {
				throw( 'Data in row #rowIndex# is missing values.  It has only #row.len()# columns, but there are at least #index# headers.' );
			}
			var data = row[ index ];
			if ( isStruct( data ) ) {
				data = data.value;
			}
			acc.maxWidth = max( acc.maxWidth, len( data ) );
			acc.medianWidth.append( len( data ) );
			return acc;
		},
		{
			"value": header,
			"maxWidth": len( arguments.header ),
			"medianWidth": [ len( arguments.header ) ],
			"medianRatio": 1
		} );
		// Finalize median calculation
		colData.medianWidth = colData.medianWidth.sort( (a,b)=>a>b );
		colData.medianWidth = max( colData.medianWidth[ int( colData.medianWidth.len() / 2 ) ], 0 );
		colData.medianRatio = max( ( (colData.maxWidth-colData.medianWidth)*data.len() ), 1 )*colData.maxWidth;
		return colData
	}

    /**
     * Prints the header row for the table.
     * @headerData The array of column headers for the table with their corresponding max widths.
     * @print A reference to the CommandBox Printer that called this table printer.
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
		print.green( variables.tableChars.headerLeftMid );
		arguments.headerData.each( ( header, index ) => {
			print.green( variables.tableChars.top );
			for ( var i = 1; i <= header.maxWidth; i++ ) {
				print.green( variables.tableChars.top );
			}
			print.green( variables.tableChars.top );
			if ( index != headerData.len() ) {
				print.green( variables.tableChars.headerMidMid );
			} else {
				print.greenLine( variables.tableChars.headerRightMid );
			}
		} );
	}

    /**
     * Prints all the data for the table.
     * @data The data for the table.
     * @headerData The array of column headers for the table with their corresponding max widths.
     * @print A reference to the CommandBox Printer that called this table printer.
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
     * @row A signle row of data for the table.
     * @headerData The array of column headers for the table with their corresponding max widths.
     * @print A reference to the CommandBox Printer that called this table printer.
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
     * @headerData The array of column headers for the table with their corresponding max widths.
     * @print A reference to the CommandBox Printer that called this table printer.
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
     * @headerData The array of column headers for the table with their corresponding max widths.
     * @print A reference to the CommandBox Printer that called this table printer.
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
     * @data The data for the table.
     * @headers The column headers for the table.  Used as the lookup keys if data is an array of structs.
     */
	private array function autoFormatData( required array headers, required array data ) {
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
     * @item The struct of data representing a single row.
     * @headers The column headers for the table used to get the needed data from the item in the correct order.
     */
	private array function getStructValues( required struct item, required array headers ) {
		return arguments.headers.map( ( key ) => {
			return item[ key ];
		} );
	}

    /**
     * Adds characters to the right of a string until the string reaches a certain length.
     * If the text is already greater than or equal to the maxWidth, the text is returned unchanged.
     * @text The text to pad.
     * @maxWidth The number of characters to pad up to.
     * @padChar The character to use to pad the text.
     */
	private string function padRight( required string text, required numeric maxWidth, string padChar = " " ) {
		var textLength = len( arguments.text );
		if ( textLength == arguments.maxWidth ) {
			return arguments.text;
		} else if( textLength > arguments.maxWidth ) {
			if( arguments.maxWidth < 4 ) {
				return left( text, arguments.maxWidth );	
			} else {
				return left( text, arguments.maxWidth-3 )&'...';				
			}
		}

		for ( var i = textLength; i < arguments.maxWidth; i ++ ) {
			arguments.text &= arguments.padChar;
		}

		return arguments.text;
	}

}
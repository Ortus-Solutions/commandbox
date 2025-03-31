/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Scott Steinbeck
*
* I print tables
*
*/
component {

    processingdirective pageEncoding='UTF-8';

    property name="print" inject="PrintBuffer";
    property name="shell" inject="shell";
	property name="convert" inject="DataConverter";
	property name="job" inject="InteractiveJob";

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
	 * @data Any type of data for the table.  Each item in the array may either be an array in the correct order matching the number of headers or a struct with keys matching the headers.
	 * @includedHeaders A list of headers to include.  Used for query inputs
     * @headerNames An list/array of column headers to use instead of the default
	 * @debug Only print out the names of the columns and the first row values
	 * @width Override the terminal width
     */

    public string function print(
		required any data=[],
        any includedHeaders="",
        any headerNames="",
		boolean debug=false,
		width=-1
    ) {

		arguments.headerNames = isArray( arguments.headerNames ) ? arrayToList( arguments.headerNames ) : arguments.headerNames;
		var dataQuery = isQuery( arguments.data ) ? arguments.data : convert.toQuery( arguments.data, arguments.headerNames );

		// Check for
		// printTable []
		// printTable [{}]
		if( !dataQuery.recordCount || !len( dataQuery.columnList )  ) {
			return 'No Data';
		}
		var includeList = isArray( arguments.includedHeaders ) ? arrayToList( arguments.includedHeaders ) : arguments.includedHeaders;
		var columns = includeList != "" ? includeList: "*";

		// validate columns first and throw our own error since the QoQ error message for invalid columns can be confusing
		columns.listEach( (c)=> {
			c = trim( c );
			// This expression will either evaluate to true or throw an exception
			listFindNoCase( dataQuery.columnList, c )
				|| c == '*'
				|| throw( message='Header name [#c#] not found.', detail='Valid header names are [#dataQuery.columnList#]', type='commandException' );
		} );

		dataQuery = queryExecute('SELECT #columns# FROM dataQuery',[],{ dbType : 'query' });

		// Extract data in array of structs
		var dataRows = convert.queryToArrayOfOrderedStructs( dataQuery );

		// Extract column names into headers
		var dataHeaders = arguments.headerNames.len() ? arguments.headerNames.listToArray() : queryColumnArray(dataQuery);
		if(arguments.debug){
			dataRows = [];
			if(dataQuery.recordcount){
				dataHeaders
				.sort( 'textnocase' )
				.each((x) => {
					dataRows.append([x,dataQuery[x][1]]);
				})
			}
			dataHeaders = ['Column','First Row Data'];

		}
		dataRows = autoFormatData( dataQuery.columnList.listToArray(), dataRows );
		dataHeaders = processHeaders( dataHeaders, dataRows, headerNames.listToArray(), width )

		printHeader( dataHeaders );
		printData( dataRows, dataHeaders );
		printTableEnd( dataHeaders );
        return print.getResult();
	}


    /**
     * Outputs a table to the screen
     * @headers An array of column headers,
     * @data An array of data for the table.
     * @headerNames Header name overrides
     */
    public array function processHeaders(
        required array headers,
        required array data,
        headerNames=[],
		width=-1
    ) {
        var headerData = arguments.headers.map( ( header, index ) => calculateColumnData( index, header, data, headerNames ), true );
		var termWidth = arguments.width;
        if( termWidth <= 0 ) {
			// If this table is going to get captured in job output, ensure it will fix based on the job depth
			if( job.getActive() ) {
				termWidth = shell.getTermWidth()-3-( job.getCurrentJobDepth() * 4 );
			} else {
				termWidth = shell.getTermWidth()-1;
			}
		}
        if( termWidth <= 0 ) {
        	termWidth = 100;
        }
        var tableWidth = headerData.reduce( (acc=0,header)=>acc+header.maxWidth+3 )+1;

        // Crunch time-- we need to shed a few pounds
        if( tableWidth > termWidth ) {
        	var overage = tableWidth-termWidth;
        	var medianRatioTotal = headerData.reduce( (acc=0,header)=>acc+( header.medianRatio ) );

        	headerData = headerData.map( (header)=>{
        		// Calculate how many characters to remove from each column based on their "squishable" ratio
        		var charsToLose = round( overage*( header.medianRatio/medianRatioTotal ) );
        		header.maxWidth=max( header.maxWidth-charsToLose, 3 );
        		return header
        	} );
        }

        var tableWidth = headerData.reduce( (acc=0,header)=>acc+header.maxWidth+3 )+1;

        // Table is still too big, time for drastic measures
        if( tableWidth > termWidth ) {
        	var lastCol = 1;
        	var totalWidth = 1;
        	// Find out how many columns will fit in the terminal
        	while( totalWidth<termWidth && lastCol <= headerData.len() ) {
        		if( totalWidth + headerData[ lastCol ].maxWidth+3 > termWidth ) {
        			break;
        		}
        		totalWidth += headerData[ lastCol ].maxWidth+3;
        		lastCol++;
        	}

        	// If there's not room for our final "..." column, then back up one col
   			if( termWidth-totalWidth < 6 ) {
   				lastCol--;
   			}
        	// Just whack off the extra columns
        	headerData = headerData.slice( 1, max( lastCol-1, 1 ) );
        	headerData.append( {
        		"value":"...",
        		"maxWidth":3,
        		"overageCol":true
        	} );

        	// This happens if the first column is still so big it won't fit and the while loop above never entered
        	if( totalWidth == 1 ) {
        		// Cut down that one column so it fits
        		headerData[1].maxWidth=max( termWidth-11, 3)
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
     * @headerNames Header name overrides
     */
	private struct function calculateColumnData( required numeric index, required string header, required array data, array headerNames=[] ) {
		var headerName = arguments.header;
		if( headerNames.len() >= index ) {
			headerName = headerNames[ index ];
		}
		var colData = arguments.data.reduce( ( acc, row, rowIndex ) => {
			if( row.len() < index ) {
				throw( 'Data in row #rowIndex# is missing values.  It has only #row.len()# columns, but there are at least #index# headers.' );
			}
			var data = row[ index ];
			if ( cellHasFormattingEmbedded( data ) ) {
				data = data.value;
			}
			acc.maxWidth = max( acc.maxWidth, len( stringify( data ) ) );
			acc.medianWidth.append( len( stringify( data ) ) );
			return acc;
		},
		{
			"value": headerName,
			"maxWidth": len( headerName ),
			"medianWidth": [ len( headerName ) ],
			"medianRatio": 1
		} );

		// Finalize median calculation
		colData.medianWidth = colData.medianWidth.sort( (a,b)=>a>b );
		colData.medianWidth = max( colData.medianWidth[ max( int( colData.medianWidth.len() / 2 ), 1 ) ], 0 );
		// This ratio represents how 'squishable' a column is as a function of the amount of whitespae and it's overall length
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
			print.green( repeatString( variables.tableChars.top, header.maxWidth ) );
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
			print.green( repeatString( variables.tableChars.top, header.maxWidth ) );
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
     * @row A single row of data for the table.
     * @headerData The array of column headers for the table with their corresponding max widths.
     */
	private void function printRow( required array row, required array headerData ) {
		print.green( variables.tableChars.left );
		arguments.headerData.each( ( header, index ) => {
			print.white( " " );
			// If this is the last column and it is an overage indicator, just print '...'
			if ( index == headerData.len() && ( header.overageCol ?: false ) ) {
				var data = '...';
			} else {
				var data = row[ index ];
			}
			var options = "white";
			if ( cellHasFormattingEmbedded( data ) ) {
				options = data.options;
				data = data.value;
			}

			print.text( padRight( stringify( data ), header.maxWidth ), options );
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
		}, true );
	}

    /**
     * Gets the required keys from the struct of data and returns them as an array of arrays.
     * @item The struct of data representing a single row.
     * @headers The column headers for the table used to get the needed data from the item in the correct order.
     */
	private array function getStructValues( required struct item, required array headers ) {
		return arguments.headers.map( ( key ) => {
			return item[ key ];
		}, true );
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
		arguments.text &= repeatString( arguments.padChar, arguments.maxWidth-textLength );
		return arguments.text;
	}

	function stringify( any data ) {
		if( isSimpleValue( data ) ) {
			return data;
		} else if (isArray(data) || isStruct(data)) {
			return SerializeJSON(data);
		} else {
			return '[#data.getClass().getName()#]';
		}
	}

	function cellHasFormattingEmbedded( data ) {
		return isStruct( data ) && data.count() == 2 && data.keyExists( 'options' ) && data.keyExists( 'value' ) && isSimpleValue( data.options );
	}

}

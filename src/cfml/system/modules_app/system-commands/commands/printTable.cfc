/**
 * Outputs a table to the screen
 */
component {

	// DI Properties
	property name="consoleLogger"			inject="logbox:logger:console";

	/**
	 * @inputOrFile.hint The text to process, or a file name with table like data in it
	 * @columns.hint A comma seperated list of column names
 	 **/
	function run(
		required string inputOrFile,
		string columns=''
	)  {

		// Treat input as a file path
		var filePath = resolvePath( arguments.inputOrFile );
		if( fileExists( filePath )) {
			arguments.inputOrFile = fileRead( filePath );
		} else {
			arguments.inputOrFile = print.unAnsi( arguments.inputOrFile );
		}

		if(isJSON(arguments.inputOrFile)) arguments.inputOrFile = deserializeJSON( arguments.inputOrFile );

		var data = normalizeData(arguments.inputOrFile);
		if(!data.len()) throw ( message = "No data provided" );

		arguments.columns = listToArray( arguments.columns );
		if(!arguments.columns.len()) arguments.columns = generateColumnNames(data[1]);

		var tableSafeData = toSafeData(data,arguments.columns);

		print.table(arguments.columns,tableSafeData)
	}

	// fill arrays and structs with columns positions/keys to make it safe for the table printer
	private function toSafeData(data, columns){
		return data.map((row) => {
			if(isStruct(row)){
				for(var i in columns){
					if(row.keyExists(i)){
						if(!isSimpleValue(row[i])) row[i] = serializeJSON(row[i]);
					} else {
						row[i] = "";
					}
				}
			} else if(isArray(row)){
				for(var i = 1; i <= columns.len(); i++){
					if(arrayIndexExists(row,i)) {
						if(!isSimpleValue(row[i])) row[i] = serializeJSON(row[i]);
					} else {
						row.append("");
					}
				}
			}
			return row;

		})
	}

	// take a simple value/array of values/or struct and normalize it to fit the table printer format
	private function normalizeData(data){
		var data = isArray(data) ? data : [data];
		return data.map((x) => {
			return (isArray(x) || isStruct(x)) ? x : [x];
		})
	}

	// create column names from data, default to col_1 ... for simple values and arrays, use key names for structs
	private function generateColumnNames (data){
		if(isSimpleValue(data)){
			return  ['col_1'];
		} else if ( isArray(data) ){
			return data.map((x,i) => 'col_' & i);
		} else if ( isStruct(data) ){
			return  structKeyArray(data);
		}
		return [];
	}


}

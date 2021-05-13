/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Scott Steinbeck
*
* Utilities converting data between formats
*
*/
component singleton {

	/**
	 * Constructor
	 */
	function init(){
		return this;
	}

	/**
     * Take any data and convert it to a query
     * @data Any type of data for the table.
     */
	public query function toQuery( required any rawData, string columns="" ){
		var data = normalizeData(rawData);
		if(!data.len()) return queryNew('empty');
		var columns = generateColumnNames(data[1], arguments.columns);
		return queryNew( columnNames=columns, data=data );
	}

	/**
     * Take a simple value/array of values/or struct and normalize it to fit the table printer format
     * @data Any type of data for the table.
     */
	public array function normalizeData(required any rawData){
		var data = isArray(rawData) ? rawData : [rawData];
		return data.map((x) => {
			if(isArray(x)) return x.map((y) => { return isSimpleValue(y) ? y : serializeJSON(y)});
			if(isStruct(x)) return x.map((k,v) => { return isSimpleValue(v) ? v : serializeJSON(v)});
			return [x]; // wrap simple data in an array
		}, true)
	}

	/**
     * Create column names from data, default to col_1 ... for simple values and arrays,
	 * Use key names for structs
     * @data Any type of data for the table.
     */
	public array function generateColumnNames (required any data, string columns="" ){
		var columnsArray = [];
		if(isSimpleValue(data)){
			columnsArray = ['col_1'];
		} else if ( isArray(data) ){
			columnsArray = data.map((x,i) => {return 'col_' & i},true);
			arguments.columns.each(function(element,index,list) {
				columnsArray[index] = element;
			})
		} else if ( isStruct(data) ){
			columnsArray = structKeyArray(data);
		}
		return columnsArray;
	}


}
component {

	processingdirective pageEncoding='UTF-8';
	property name="convert" inject="DataConverter";

	/**
	 * @data The text to process with table like data in it
	 * @select A SQL list of column names, eg. "name,version"
	 * @where A SQL where filter used in a query of queries, eg. "name like '%My%'"
	 * @orderby A SQL order by used in a query of queries, eg. "name asc,version desc"
	 * @limit A SQL limit/offset used in a query of queries, eg. "5 or 5,10 (eg. offset 5 limit 10)"
	 * @headerNames An list of column headers to use instead of the default
 	 **/
	function run(
		required string data,
		string select='',
		string where='',
		string orderby='',
		string limit='',
		string headerNames=''
	)  {

		// Treat input as a potential file path
		arguments.data = print.unAnsi( arguments.data );

		//deserialize data if in a JSON format
		if(isJSON(arguments.data)) arguments.data = deserializeJSON( arguments.data, false );

		//format inputs into valid sql parts
		var dataQuery = isQuery( arguments.data ) ? arguments.data : convert.toQuery(arguments.data, arguments.headerNames);

		//setup query pieces
		var columnFilter = arguments.select != "" ? arguments.select: "*";
		var whereFilter = arguments.where != "" ? "Where " & arguments.where: "";
		var orderByFilter = arguments.orderby != "" ? "Order By " & arguments.orderby : "";

		//Limit Data
		if(arguments.limit != ""){
			var limitoffset = listToArray(arguments.limit);
			if(limitoffset.len() == 1){
				var limit = limitoffset[1];
				var offset = 0;
			} else {
				var limit = limitoffset[2];
				var offset = limitoffset[1];
			}
			dataQuery = dataQuery.slice(offset, limit);
		};

		// Run query of queries
		var sqlstatement  = 'SELECT #columnFilter# FROM dataQuery #whereFilter# #orderByFilter#';
		dataQueryResults = queryExecute(sqlstatement,[],{ dbType : 'query', returnType : 'array' });

		print.line(dataQueryResults);

	}

}

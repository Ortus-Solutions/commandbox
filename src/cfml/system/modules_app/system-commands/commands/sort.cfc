/**
 * Sort a list of input lines. You can control direction and type of sort.
 * .
 * {code:bash}
 * cat names.txt | sort
 * {code}
 * .
 * You can do a case sensitive or numeric sort
 * .
 * {code:bash}
 * cat names.txt | sort type=text
 * cat names.txt | sort type=numeric
 * {code}
 * .
 * You can also change the direction of the sort
 * .
 * {code:bash}
 * cat names.txt | sort direction=desc
 * {code}
 *
 **/
component {

	/**
	 * @input The piped input to be checked.
	 * @type Sort by "text" (case sensitive), "textnocase" (case insensitive), or "numeric"
	 * @direction Sort "asc" (ascending), or "desc" (descending)
	 * @type.options text,textnocase,numeric
	 * @direction.options asc,desc
	 **/
	function run( input='', type="textnocase", direction="asc" ) {
		print.text(
			listToArray( arguments.input, chr(13)&chr(10) )
				.sort( type, direction )
				.toList( CR )
		);
	}

}

/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* Utilities for dealing with formmating HTML and ANSI output
*
*/
component singleton {

	property name="print" inject="print";
	property name="CR" inject="CR@constants";
	
	function init(){
		
		variables.stringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
		return this;
	}

	/**
	 * Converts HTML into plain text
	 * @html.hint HTML to convert
  	 **/
	function unescapeHTML(required html) {
    	var text = StringEscapeUtils.unescapeHTML( html );
    	//text = replace(text,"<" & "br" & ">","","all");
       	return text;
	}

	/**
	 * Converts HTML into ANSI text
	 * @html.hint HTML to convert
  	 **/
	function HTML2ANSI( required html ) {
    	var text = html;
    	
    	if( len( trim( text ) ) == 0 ) {
    		return "";
    	}    	
    	text = ansifyHTML( text, "b", "bold" );
    	text = ansifyHTML( text, "strong", "bold" );
    	text = ansifyHTML( text, "em", "underline" );
    	
  	 	// Replace br tags (and any whitespace/line breaks after them) with a CR
  	 	text = reReplaceNoCase( text , "<br[^>]*>\s*", CR, 'all' );
    	    	
    	var t='div';
    	var matches = REMatch('(?i)<#t#[^>]*>(.*?)</#t#>', text);
    	for(var match in matches) {
    		var blockText = reReplaceNoCase(match,"<#t#[^>]*>(.*?)</#t#>","\1") & CR;
    		text = replace(text,match,blockText,"one");
    	}
    	
    	// Remove remaining HTML
    	// If you have any < characters in your string that aren't HTML, this will truncate the text 
    	text = reReplaceNoCase(text, "<.*?>","","all");
    	
    	// Turn any escaped HTML entities into their true form
    	text = unescapeHTML( text );
       	return text;
	}

	/**
	 * Converts HTML matches into ANSI text
	 * @text.hint HTML to convert
	 * @tag.hint HTML tag name to replace
	 * @ansiCode.hint ANSI code to replace tag with
  	 **/
	function ansifyHTML(text,tag,ansiCode) {
    	var t=tag;
    	var matches = REMatch('(?i)<#t#[ ^>]*>(.+?)</#t#>', text);
    	for(var match in matches) {
    		// This doesn't really work inside of a larger string that you are applying formatting to
    		// The end of the boldText clears all formatting, and the rest of the string is just plain.
    		var boldtext = print[ ansiCode ]( reReplaceNoCase(match,"<#t#[^>]*>(.+?)</#t#>","\1") );
    		text = replace(text,match,boldtext,"one");
    	}
    	return text;
	}
	/**
	 * Pretty JSON
	 * @json.hint A string containing JSON, or a complex value that can be serialized to JSON
 	 **/
	public function formatJson( json ) {
		
		// Overload this method to accept a struct or array
		if( !isSimpleValue( arguments.json ) ) {
			arguments.json = serializeJSON( arguments.json );
		}
		
		var retval = createObject("java","java.lang.StringBuilder").init('');
		var str = json;
	    var pos = 0;
	    var strLen = str.length();
		var indentStr = '    ';
	    var newLine = cr;
		var char = '';
		var inQuote = false;
		var isEscaped = false;

		for (var i=0; i<strLen; i++) {
			char = str.substring(i,i+1);
			
			if( isEscaped ) {
				isEscaped = false;
				retval.append( char );
				continue;
			}
			
			if( char == '\' ) {
				isEscaped = true;
				retval.append( char );
				continue;
			}
			
			if( char == '"' ) {
				if( inQuote ) {
					inQuote = false;
				} else {
					inQuote = true;					
				}
				retval.append( char );
				continue;
			}
			
			if( inQuote ) {
				retval.append( char );
				continue;
			}	
			
			
			if (char == '}' || char == ']') {
				retval.append( newLine );
				pos = pos - 1;
				for (var j=0; j<pos; j++) {
					retval.append( indentStr );
				}
			}
			retval.append( char );
			if (char == '{' || char == '[' || char == ',') {
				retval.append( newLine );
				if (char == '{' || char == '[') {
					pos = pos + 1;
				}
				for (var k=0; k<pos; k++) {
					retval.append( indentStr );
				}
			}
		}
		return retval.toString();
	}
}
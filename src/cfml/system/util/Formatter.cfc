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
	property name="JSONPrettyPrint" inject="provider:JSONPrettyPrint";

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
	function HTML2ANSI( required html, additionalFormatting='' ) {
    	var text = html;

    	if( len( trim( text ) ) == 0 ) {
    		return "";
    	}

    	// Trim all lines.  leading/trailing whitespace in HTML is not useful
    	text = text.listToArray( chr( 13 ) & chr( 10 ) ).map( function( i ) {
    		return trim( i );
    	} ).toList( chr( 10 ) );

    	// Remove style and script blocks
    	text = reReplaceNoCase(text, "<style>.*</style>","","all");
    	text = reReplaceNoCase(text, "<script[^>]*>.*</script>","","all");

    	text = ansifyHTML( text, "b", "bold", additionalFormatting );
    	text = ansifyHTML( text, "strong", "bold", additionalFormatting );
    	text = ansifyHTML( text, "em", "underline", additionalFormatting );

  	 	// Replace br tags (and any whitespace/line breaks after them) with a CR
  	 	text = reReplaceNoCase( text , "<br[^>]*>\s*", CR, 'all' );

    	var t='div';
    	var matches = REMatch('(?i)<#t#[^>]*>(.*?)</#t#>', text);
    	for(var match in matches) {
    		var blockText = reReplaceNoCase(match,"<#t#[^>]*>(.*?)</#t#>","\1") & CR;
    		text = replace(text,match,blockText,"one");
    	}

    	// If you have any < characters in your string that aren't HTML, this will truncate the text
    	text = reReplaceNoCase(text, "<.*?>","","all");

    	text = reReplaceNoCase(text, "[\n]{2,}",chr( 10 ) & chr( 10 ),"all");



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
	function ansifyHTML(text, tag, ansiCode, additionalFormatting) {
    	var t=tag;
    	var matches = REMatch('(?i)<#t#[ ^>]*>(.+?)</#t#>', text);
    	for(var match in matches) {
    		// This doesn't really work inside of a larger string that you are applying formatting to
    		// The end of the boldText clears all formatting, and the rest of the string is just plain.
    		var boldtext = print[ ansiCode ]( reReplaceNoCase(match,"<#t#[^>]*>(.+?)</#t#>","\1") ) & print.text( '', additionalFormatting, true );
    		text = replace(text,match,boldtext,"one");
    	}
    	return text;
	}
	/**
	 * Pretty JSON
	 * @json.hint A string containing JSON, or a complex value that can be serialized to JSON
 	 **/
	public function formatJson( json ) {
		// This is an external lib now.  Leaving here for backwards compat.
		return JSONPrettyPrint.formatJSON( json );
	}
}

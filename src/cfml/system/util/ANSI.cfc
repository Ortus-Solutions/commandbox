component{

	function init(){
		
		variables.stringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
		variables.system = createObject( "java", "java.lang.System" );
		variables.cr = System.getProperty("line.separator");
		variables.print = new commandbox.system.util.Print();
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
  	 	text = reReplaceNoCase( text , "<br[^>]*>", CR, 'all' );
    	    	
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
    	var matches = REMatch('(?i)<#t#[^>]*>(.+?)</#t#>', text);
    	for(var match in matches) {
    		// This doesn't really work inside of a larger string that you are applying formatting to
    		// The end of the boldText clears all formatting, and the rest of the string is just plain.
    		var boldtext = print[ ansiCode ]( reReplaceNoCase(match,"<#t#[^>]*>(.+?)</#t#>","\1") );
    		text = replace(text,match,boldtext,"one");
    	}
    	return text;
	}
}
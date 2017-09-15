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

	property name="shell" inject="shell";
	property name="print" inject="print";
	property name="JSONPrettyPrint" inject="provider:JSONPrettyPrint";

	function init(){

		variables.stringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
		variables.CR = chr( 13 );
		variables.LF = chr( 10 );
		variables.CRLF = CR & LF;
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
    	text = text.listToArray( CRLF ).map( function( i ) {
    		return trim( i );
    	} ).toList( chr( 10 ) );

    	// Remove style and script blocks
    	text = reReplaceNoCase(text, "<style>.*</style>","","all");
    	text = reReplaceNoCase(text, "<script[^>]*>.*</script>","","all");

    	text = ansifyHTML( text, "b", "bold", additionalFormatting );
    	text = ansifyHTML( text, "strong", "bold", additionalFormatting );
    	text = ansifyHTML( text, "em", "underline", additionalFormatting );

  	 	// Replace br tags (and any whitespace/line breaks after them) with a LF
  	 	text = reReplaceNoCase( text , "<br[^>]*>\s*", LF, 'all' );

    	var t='div';
    	var matches = REMatch('(?i)<#t#[^>]*>(.*?)</#t#>', text);
    	for(var match in matches) {
    		var blockText = reReplaceNoCase(match,"<#t#[^>]*>(.*?)</#t#>","\1") & LF;
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
	function ansifyHTML( text, tag, ansiCode, additionalFormatting ) {
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
	 * Converts markdown into ANSI text
	 * @markdown Text to convert
  	 **/
	function MD2ANSI( required markdown, additionalFormatting='' ) {
    	var text = markdown;
		var inCodeBlock = false;
		var codeBlockContents = '';
		var formattedText = [];
		var previousLineNeedsPadding = false;
		
    	if( len( trim( text ) ) == 0 ) {
    		return "";
    	}
    	
		// Turn all line endings into LF or it will be impossible to 
		// parse the lines and keep empty rows.
		text = replace( text, CRLF, LF, 'all' );
		text = replace( text, CR, LF, 'all' );

		text
			.listToArray( LF, true )
			.each( function( line ) {
				
				
				// Detect the start of code blocks
				if( line.trim().startsWith( '```' ) && !inCodeBlock ) {
					inCodeBlock=true;
					return;
				}
				
				// If we're already in a code block
				if( inCodeBlock ) {
					// Is this the end of the code block?
					if( line.trim().startsWith( '```' ) ) {
						inCodeBlock = false;
						
						// Turn code block into array,
						var codeArray = codeBlockContents
							.listToArray( LF, true )
							// swap all tabs for spaces to keep spacing
							.map( function( codeLine ) {
								return replaceNoCase( codeLine, chr( 9 ), '  ', 'all' );
							} )
							// pad before and after
							.prepend( '' )
						
						// Find the longest line of code
						var longestLine = codeArray.reduce( function( prev, codeLine) {
							return max( prev, codeLine.len() );
						}, 0 ) + 2;
						
						// pad each row so the lengths are all the same
						codeArray = codeArray.map( function( codeLine ) {
							return '  ' & print.indentedBlackOnWhite( codeLine & repeatString( ' ', longestLine-codeLine.len() ) );
						} );
						
						// Turn array back into string with 
						line = LF & codeArray.toList( LF ) & print.text( '', additionalFormatting, true );
						codeBlockContents = '';
						previousLineNeedsPadding = true;
					} else {
						codeBlockContents &= line & LF;
					return;
					}
				} else {
					
					// Add extra line after heading and code blocks if it's not already there
					if( previousLineNeedsPadding && !line.trim() == '' ) {
						formattedText.append( '' );
					}
					
					// Let the next interation know we just had a section heading
					if( reFindNoCase( '^##{1,4}\s*(.*)$', line ) ) {
						previousLineNeedsPadding = true;
					} else {
						previousLineNeedsPadding = false;
					}
					
					// Convert section headings
					line = reReplaceNoCase( line, '^##{1,4}\s*(.*)$', print.bold( LF & '\1' ) & print.text( '', additionalFormatting, true ) );
					
					// Convert inline blocks
					line = reReplaceNoCase( line, '`([^`]*)`', print.bold( '\1' ) & print.text( '', additionalFormatting, true ), 'all' );
					
					// Convert bold blocks
					line = reReplaceNoCase( line, '\*\*([^`]*)\*\*', print.bold( '\1' ) & print.text( '', additionalFormatting, true ), 'all' );
					
					// Convert italics blocks
					line = reReplaceNoCase( line, '`([^`]*)`', print.bold( '\1' ) & print.text( '', additionalFormatting, true ), 'all' );
					
					// Indent lists
					if( line.startsWith( '* ' ) || line.startsWith( '- ' ) ) {
						line = '  ' & line;	
					}
					
					// Horizontal Rule
					if( line.trim().reFind( '^([-]{3,}|[_]{3,}|[*]{3,})$' ) ) {
						// Repeat across 75% of the terminal width
						line = repeatString( '_', int( shell.getTermWidth() * .75 ) );
						previousLineNeedsPadding = true; 
					}
					
				}
				
				formattedText.append( line );
			} );
			
			
		return formattedText.toList( LF );

	}
	
    	
	
	/**
	 * Pretty JSON
	 * @json.hint A string containing JSON, or a complex value that can be serialized to JSON
 	 **/
	public function formatJson( json, indtent, lineEnding ) {
		// This is an external lib now.  Leaving here for backwards compat.
		return JSONPrettyPrint.formatJSON( argumentCollection=arguments );
	}
}

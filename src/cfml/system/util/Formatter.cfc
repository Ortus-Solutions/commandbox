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

	// DI
    property name="configService" inject="ConfigService";
	property name="shell" inject="shell";
	property name="print" inject="print";
	property name="JSONPrettyPrint" inject="provider:JSONPrettyPrint";

	/**
	 * Constructor
	 */
	function init(){
		variables.stringEscapeUtils = createObject( "java", "org.apache.commons.lang.StringEscapeUtils" );
		variables.CR = chr( 13 );
		variables.LF = chr( 10 );
		variables.CRLF = CR & LF;
		return this;
	}

	/**
	 * Create a URL safe slug from a string
	 * @str The string to slugify
	 * @maxLength The maximum number of characters for the slug
	 * @allow A regex safe list of additional characters to allow
	 */
	function slugify( required str, numeric maxLength=0, allow="" ){
		// Cleanup and slugify the string
		var slug 	= lcase( trim( arguments.str ) );
		slug 		= replaceList( slug, '#chr(228)#,#chr(252)#,#chr(246)#,#chr(223)#', 'ae,ue,oe,ss' );
		slug 		= reReplace( slug, "[^a-z0-9-\s#arguments.allow#]", "", "all" );
		slug 		= trim ( reReplace( slug, "[\s-]+", " ", "all" ) );
		slug 		= reReplace( slug, "\s", "-", "all" );

		// is there a max length restriction
		if( arguments.maxlength ){ slug = left( slug, arguments.maxlength ); }

		return slug;
	}

	/**
	 * Converts HTML into plain text
	 * @html HTML to convert
  	 **/
	function unescapeHTML( required html ){
    	var text = StringEscapeUtils.unescapeHTML( html );
    	//text = replace(text,"<" & "br" & ">","","all");
       	return text;
	}

	/**
	 * Converts HTML into ANSI text
	 * @html HTML to convert
  	 **/
	function HTML2ANSI( required html, additionalFormatting='' ) {
    	var text = html;

    	if( len( trim( text ) ) == 0 ) {
    		return "";
    	}

    	// Trim all lines.  leading/trailing whitespace in HTML is not useful
    	text = text.listToArray( CRLF ).map( function( i ) {
    		return trim( i );
    	} ).toList( '' );

    	// Remove style and script blocks
    	text = reReplaceNoCase(text, "<style>.*</style>","","all");
    	text = reReplaceNoCase(text, "<script[^>]*>.*</script>","","all");

    	text = ansifyHTML( text, "b", "bold", additionalFormatting );
    	text = ansifyHTML( text, "strong", "bold", additionalFormatting );
    	text = ansifyHTML( text, "em", "underline", additionalFormatting );

    	var matches = REMatch('(?i)<div[^>]*>(.*?)</div>', text);
    	for(var match in matches) {
    		var blockText = reReplaceNoCase(match,"<div[^>]*>(.*?)</div>","\1") & LF;
    		text = replace(text,match,blockText,"one");
    	}

    	var matches = REMatch('(?i)<blockquote[^>]*>(.*?)</blockquote>', text);
    	for(var match in matches) {
    		var blockText = reReplaceNoCase(match,"<blockquote[^>]*>(.*?)</blockquote>","\1");
    		blockText = '<br>' & blockText & '<br>';
    		blockText = reReplaceNoCase( blockText, '<br[^>]*>', '<br>&nbsp;&nbsp;&nbsp;&nbsp;', 'all' );
    		text = replace(text,match,blockText,"one");
    	}

  	 	text = reReplaceNoCase( text , "</td[^>]*>", ' ', 'all' );
  		text = reReplaceNoCase( text , "</tr[^>]*>", LF & LF, 'all' );

  	 	// Replace br tags (and any whitespace/line breaks after them) with a LF
  	 	text = reReplaceNoCase( text , "<br[^>]*>[ 	]*", LF, 'all' );

    	// If you have any < characters in your string that aren't HTML, this will truncate the text
    	text = reReplaceNoCase(text, "<.*?>","","all");

    	text = reReplaceNoCase(text, "[\n]{2,}",LF & LF,"all");

    	// Turn any escaped HTML entities into their true form
    	text = unescapeHTML( text );
       	return text;
	}

	/**
	 * Converts HTML matches into ANSI text
	 * @text HTML to convert
	 * @tag HTML tag name to replace
	 * @ansiCode ANSI code to replace tag with
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
	 * @json A string containing JSON, or a complex value that can be serialized to JSON
	 **/
	public function formatJson( any json, string indent, string lineEnding, boolean spaceAfterColon, string sortKeys, struct ansiColors ) {
		
		// If these settings are defined, they take over and are used
		// ansiColors are NOT defauled here since there are cases in which we DON'T want any color coding.
		// Therefore, ansiColors default need to be grabbed at the code which is calling this method if and
		// only if that code needs coloring to be applied.
		if( configService.settingExists( 'json.indent' ) ) {
			indent = configService.getSetting( 'json.indent' );
		}		
		if( configService.settingExists( 'json.lineEnding' ) ) {
			lineEnding = configService.getSetting( 'json.lineEnding' );
		}		
		if( configService.settingExists( 'json.spaceAfterColon' ) ) {
			spaceAfterColon = configService.getSetting( 'json.spaceAfterColon' );
		}		
		if( configService.settingExists( 'json.sortKeys' ) ) {
			sortKeys = configService.getSetting( 'json.sortKeys' );
		}
		
		// This is an external lib now.  Leaving here for backwards compat.
		return JSONPrettyPrint.formatJSON( argumentCollection = arguments );
	}
}

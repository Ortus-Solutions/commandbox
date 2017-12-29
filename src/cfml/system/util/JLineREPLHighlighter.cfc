/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
* I am a JLine highighter class that attempts to highlight the command portion of the input buffer
*/
component {
	
	// DI
	property name='print'			inject='print';
	property name='shell'			inject='provider:shell';
	
	function init() {
		variables.functionList = getFunctionList()
			.keyArray()
			// Add in member function versions of functions
			.reduce( function( orig, i ) {
				orig.append( i );				
				if( reFind( 'array|struct|query|image|spreadsheet|XML', i ) ) {
					orig.append( i.reReplaceNoCase( '(array|struct|query|image|spreadsheet|XML)(.+)', '\2' ) );
				}
				return orig;
			}, [] )
			// Sort function names longest to shortest
			.sort( function(a,b){
				if( a.len() > b.len() ) return -1;
				if( a.len() < b.len() ) return 1;
				return 0; 
			} );
		
		variables.reservedWords = [
			'if',
			'else',
			'try',
			'catch',
			'var',
			'for',
			'default',
			'switch',
			'case',
			'continue',
			'import',
			'finally',
			'local',
			'interface',
			'true',
			'false',
			'return',
			'in'
		];
		return this;
	}
	
	function highlight( reader, buffer ) {
		
		// Highlight CF function names
		for( var func in functionList ) {
			// Find function names that are at the line start or prepended with a space, curly, or period and ending with an opening paren
			buffer = reReplaceNoCase( buffer, '(^|[ \.\{\}])(#func#)(\()', '\1' & print.cyan( '\2' ) & '\3', 'all' );
		}
		
		// highight reserved words
		for( var reservedWord in reservedWords ) {
			// Find keywords, bookended by a space, curly, paren, or semicolon. Or, of course, the start/end of the line
			buffer = reReplaceNoCase( buffer, '(^|[ \{\}])(#reservedWord#)($|[ ;\(\{\}])', '\1' & print.cyanBold( '\2' ) & '\3', 'all' );
		}
		
		return createObject("java","org.jline.utils.AttributedString").fromAnsi( buffer );	
	}
	
}
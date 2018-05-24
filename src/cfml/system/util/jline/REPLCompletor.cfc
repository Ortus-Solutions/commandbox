/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I handle tab completion in the shell
*
*/
component singleton {

	//DI
	property name='shell' inject='Shell';


	/**
	 * Constructor
	 **/
	function init() {
		variables.functionList = getFunctionList().keyArray();
		variables.memberFunctionList = variables.functionList
			.reduce( function( orig, i ) {	
				if( reFind( 'array|struct|query|image|spreadsheet|XML', i ) ) {
					orig.append( i.reReplaceNoCase( '(array|struct|query|image|spreadsheet|XML)(.+)', '\2' ) );
				}
				return orig;
			}, [] );
		variables.executor = '';
		return this;
	}

	function setCurrentExecutor( required executor ) {
		variables.executor = arguments.executor;
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	numeric function complete( reader, parsedLine, candidates )  {

		var buffer = parsedLine.word();		
		var javaCandidates = candidates;
		arguments.candidates = [];
		
		// Only suggest function names if there's a word being typed.
		if( buffer.len() ) {
			
			// Loop over all the possibilities at this level
			for( var func in variables.functionList ) {
				// Match the partial bit if it exists
				if( lcase( func ).startsWith( lcase( buffer ) ) ) {
					// Add extra space so they don't have to
					candidates.add( func );
				}
			}
			
		}
		
		// Only suggest member function names if there's a word being typed and there's a period in it
		if( buffer.len() && buffer.listLen( '.' ) > 1 ) {
			var start = buffer.listDeleteAt( buffer.listLen( '.' ), '.' );
			buffer = buffer.listLast( '.' );
			// Loop over all the possibilities at this level
			for( var func in variables.memberFunctionList ) {
				// Match the partial bit if it exists
				if( lcase( func ).startsWith( lcase( buffer ) ) ) {
					// Add extra space so they don't have to
					candidates.add( start & '.' & func );
				}
			}
			
		}
		
		
		if( !isSimpleValue( executor ) ) {
			candidates.append( executor.getCurrentVariables(), true );
		}
		
		createCandidates( candidates, javaCandidates );
		return;
			
	}


	/**
	* JLine3 needs an array of Java objects, so convert our array of strings to that
 	**/
	private function createCandidates( candidates, javaCandidates ) {
		
		candidates.each( function( candidate ){
				
			var thisCandidate = candidate.listLast( ' ' ) & ( candidate.endsWith( ' ' ) ? ' ' : '' );
						
			javaCandidates.append(
				createObject( 'java', 'org.jline.reader.Candidate' )
					.init(
						thisCandidate,				// value
						thisCandidate,				// displ
						javaCast( 'null', '' ),		// group      candidate.startsWith( '--' ) ? 'flags' : 'non-flags', 
						javaCast( 'null', '' ), 		// descr 
						javaCast( 'null', '' ), 		// suffix
						javaCast( 'null', '' ), 		// key
						false 						// complete
					)
			);
		} );
		
	}

}

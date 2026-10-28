/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* JLine parsed argument list
*
*/
component {

	/**
	* @line the raw line from the buffer
	* @cursor the position of the cursor on the line
	* @tokens the array of parsed tokens from the CommandBox Parser
	* @context ParseContext enum from org.jline.reader.Parser - can be UNSPECIFIED, ACCEPT_LINE, COMPLETE, SECONDARY_PROMPT
	*/
	function init(string line, numeric cursor, array tokens, any context) {
		variables.line = line;
		variables.cursor = arguments.cursor;
		variables.tokens = arguments.tokens;
		variables.context = arguments.context;
		return this;
	}

	/**
	* The unparsed line
	* This was passed into the parse function
	*/
	function line() {
		return variables.line;
	}

	/**
	* The cursor position within the line
	* This was passed into the parse function
	*/
	function cursor() {
		return variables.cursor;
	}

	/**
	* The parsed list of words in the raw line
	* This is the array of tokens that were computed by our parser and passed
	* in - with one difference. Completions in CommandBox are always done with
	* respect to the last word on the line, so that word needs to be unquoted
	* for JLine so it can match completions correctly.
	*/
	function words() {
		return variables.tokens.map( ( t, i ) => i == tokens.len() ? word() : t );
	}

	/**
	* The index of the current word (the word the cursor is in) in the list of words
	* The last word is regarded as always being the current word for now
	*/
	function wordIndex() {
		return max( variables.tokens.len() - 1, 0 );
	}

	/**
	* This is the word the cursor is currently in - for our purposes it is always the last word.
	* In order for quoted completions to work, this is expected to have any quotes wrapping the word
	* stripped. (JLine also expects it to have escapes removed, but for our purposes unquoting
	* seems sufficient.)
	*/
	function word() {
		return unquote( token() );
	}

	/**
	* The cursor position within the current word (unquoted, unescaped)
	* This is not currently computed so just return the length of the current word
	*/
	function wordCursor() {
		return word().len();
	}

	/**
	* The cursor position within the current word in its raw (quoted and escaped) form
	* JLine uses this to correctly backspace the current word on the raw line when writing
	* a completion to the buffer.
	* This is not currently computed so just return the length of the current token
	*/
	function rawWordCursor() {
		return token().len();
	}


	/**
	* The length of the current word in its raw (quoted and escaped) form
	* JLine uses this to correctly backspace the current word on the raw line when writing
	* a completion to the buffer.
	*/
	function rawWordLength() {
		return token().len();
	}

	/**
	* Escapes a completion candidate before writing it to the buffer - this method can be used
	* to quote completions that contain spaces.
	*
	* JLine will also use this method to backspace the current word from the buffer - not sure
	* why it uses this in certain cases instead of the `rawWordXXXX()` methods above. But since it does,
	* this method can be used to ensure the correct number of characters are removed.
	* `complete` will generally match up with whether completion candidates are marked as complete,
	* however, when choosing from a menu this is hard coded as true, and when backspacing the current word
	* it is hard coded as false. So this needs to be worked around for now.
	*
	* @candidate a string containing a completion candidate to be escaped - might also be the current word so Jline can backspace it
	* @complete a boolean indicating whether this completion candidate is considered complete
	*/
	function escape( string candidate, boolean complete ) {
		// check to see if we are being asked to escape the current word in the line
		// if that is the case this is most likely to backspace it, so to ensure this happens
		// correctly just return the raw last token
		if ( candidate == word() ) {
			return token();
		}

		var param = namedParam( candidate );

		// If this completion candidate contains spaces and does not already contain quotes then it needs to be quoted
		if ( find( ' ', param.value ) && !reFind( '(?:^|[^\\])[''"]', param.value ) ) {
			// JLine's implementation only adds the closing quote for `complete` candidates so copy that for now
			// This hard codes double quotes - we could also inspect the current token to see if a quote
			// is already present and use the same quote type if so.
			param.value = '"' & param.value & ( complete ? '"' : '' );
		}

		return ( param.name.len() ? param.name & '=' : '' ) & param.value;
	}

	private function token() {
		return variables.tokens.len() ? variables.tokens.last() : '';
	}

	private function namedParam( token ) {
		var name = '';
		var value = token;
		if ( listLen( token, '=' ) > 1 ) {
			name = listFirst( token, '=' );
			value = listRest( token, '=' );
		}
		return { name: name, value: value };
	}

	private function unquote( token ) {
		var param = namedParam( token );

		if ( [ '"', '''' ].find( param.value.left( 1 ) ) ) {
			var quote = param.value.left( 1 );
			param.value = mid( param.value, 2, len( param.value ) - 1 );;
			if ( param.value.right( 1 ) == quote ) {
				param.value = mid( param.value, 1, len( param.value ) - 1 );
			}
		}

		return ( param.name.len() ? param.name & '=' : '' ) & param.value;
	}

}

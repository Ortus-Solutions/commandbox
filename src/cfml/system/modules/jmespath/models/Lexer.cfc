component displayname="Lexer" {

    variables.TOK_EOF = 'EOF';
    variables.TOK_UNQUOTEDIDENTIFIER = 'UnquotedIdentifier';
    variables.TOK_QUOTEDIDENTIFIER = 'QuotedIdentifier';
    variables.TOK_RBRACKET = 'Rbracket';
    variables.TOK_RPAREN = 'Rparen';
    variables.TOK_COMMA = 'Comma';
    variables.TOK_COLON = 'Colon';
    variables.TOK_RBRACE = 'Rbrace';
    variables.TOK_NUMBER = 'Number';
    variables.TOK_CURRENT = 'Current';
    variables.TOK_EXPREF = 'Expref';
    variables.TOK_PIPE = 'Pipe';
    variables.TOK_OR = 'Or';
    variables.TOK_AND = 'And';
    variables.TOK_EQ = 'EQ';
    variables.TOK_GT = 'GT';
    variables.TOK_LT = 'LT';
    variables.TOK_GTE = 'GTE';
    variables.TOK_LTE = 'LTE';
    variables.TOK_NE = 'NE';
    variables.TOK_FLATTEN = 'Flatten';
    variables.TOK_STAR = 'Star';
    variables.TOK_FILTER = 'Filter';
    variables.TOK_DOT = 'Dot';
    variables.TOK_NOT = 'Not';
    variables.TOK_LBRACE = 'Lbrace';
    variables.TOK_LBRACKET = 'Lbracket';
    variables.TOK_LPAREN = 'Lparen';
    variables.TOK_LITERAL = 'Literal';
    // The "&", "[", "<", ">" tokens
    // are not in basicToken because
    // there are two token variants
    // ("&&", "[?", "<=", ">=").  This is specially handled
    // below.
    variables.basicTokens = {
        '.': TOK_DOT,
        '*': TOK_STAR,
        ',': TOK_COMMA,
        ':': TOK_COLON,
        '{': TOK_LBRACE,
        '}': TOK_RBRACE,
        ']': TOK_RBRACKET,
        '(': TOK_LPAREN,
        ')': TOK_RPAREN,
        '@': TOK_CURRENT
    };
    variables.operatorStartToken = {
        '<': true,
        '>': true,
        '=': true,
        '!': true
    };
    variables.skipChars = {' ': true, '#chr(13)#': true, '#chr(10)#': true};

    function isAlpha(ch) {
        return (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        ch == '_';
    }
    function isNum(ch) {
        return (ch >= '0' && ch <= '9') ||
        ch == '-';
    }
    function isAlphaNum(ch) {
        return (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
        ch == '_';
    }

    function tokenize(stream) {
        var tokens = [];
        this._current = 1;
        var start;
        var identifier;
        var token;
        while (this._current <= stream.len()) {
            if (isAlpha(stream[this._current])) {
                start = this._current;
                identifier = this._consumeUnquotedIdentifier(stream);
                tokens.append({type: TOK_UNQUOTEDIDENTIFIER, value: identifier, start: start});
            } else if (!isNull(basicTokens[stream[this._current]])) {
                tokens.append({type: basicTokens[stream[this._current]], value: stream[this._current], start: this._current});
                this._current++;
            } else if (isNum(stream[this._current])) {
                token = this._consumeNumber(stream);
                tokens.append(token);
            } else if (stream[this._current] == '[') {
                // No need to increment this._current.  This happens
                // in _consumeLBracket
                token = this._consumeLBracket(stream);
                tokens.append(token);
            } else if (stream[this._current] == '"') {
                start = this._current;
                identifier = this._consumeQuotedIdentifier(stream);
                tokens.append({type: TOK_QUOTEDIDENTIFIER, value: identifier, start: start});
            } else if (stream[this._current] == "'") {
                start = this._current;
                identifier = this._consumeRawStringLiteral(stream);
                tokens.append({type: TOK_LITERAL, value: identifier, start: start});
            } else if (stream[this._current] == '`') {
                start = this._current;
                variables.literal = this._consumeLiteral(stream);
                tokens.append({type: TOK_LITERAL, value: literal, start: start});
            } else if (operatorStartToken.keyExists(stream[this._current])) {
                tokens.append(this._consumeOperator(stream));
            } else if (skipChars.keyExists(stream[this._current])) {
                // Ignore whitespace.
                this._current++;
            } else if (stream[this._current] == '&') {
                start = this._current;
                this._current++;
                if (stream[this._current] == '&') {
                    this._current++;
                    tokens.append({type: TOK_AND, value: '&&', start: start});
                } else {
                    tokens.append({type: TOK_EXPREF, value: '&', start: start});
                }
            } else if (stream[this._current] == '|') {
                start = this._current;
                this._current++;
                if (stream[this._current] == '|') {
                    this._current++;
                    tokens.append({type: TOK_OR, value: '||', start: start});
                } else {
                    tokens.append({type: TOK_PIPE, value: '|', start: start});
                }
            } else {
                throw( message= 'Unknown character', type="JMESError", detail= 'Unknown character:(' & asc(stream[this._current]) & ')');
            }
        }

        return tokens;
    }

    function slice(str, startIndex, endIndex) {
        return mid(str, startIndex, endIndex - startIndex);
    }

    function _consumeUnquotedIdentifier(stream) {
        var start = this._current;
        this._current++;
        while (this._current <= stream.len() && isAlphaNum(stream[this._current])) {
            this._current++;
        }
        return slice(stream, start, this._current);
    }

    function _consumeQuotedIdentifier(stream) {
        //echo('_consumeQuotedIdentifier ' & stream);
        var start = this._current;
        this._current++;
        var maxLength = stream.len();
        while ( this._current <= maxLength && stream[this._current] != '"') {
            // You can escape a double quote and you can escape an escape.
            var current = this._current;
            if (
                stream[current] == '\' && (
                    stream[current + 1] == '\' ||
                    stream[current + 1] == '"'
                )
            ) {
                current += 2;
            } else {
                current++;
            }
            this._current = current;
        }
        this._current++;
        stream = slice(stream, start, this._current);
        //stream = CharsetDecode(stream, "utf-8");

        //echo("[" & stream & ' -- ' & start  & ' -- ' & this._current & "] ->" & val & "<br/>");
        return parseJson(stream);
    }

    function _consumeRawStringLiteral(stream) {
        //echo('_consumeRawStringLiteral ' & stream);
        var start = this._current;
        this._current++;
        var maxLength = stream.len();
        while (this._current <= maxLength && stream[this._current] != "'") {
            // You can escape a single quote and you can escape an escape.
            var current = this._current;
            if (
                stream[current] == '\' && (
                    stream[current + 1] == '\' ||
                    stream[current + 1] == "'"
                )
            ) {
                current += 2;
            } else {
                current++;
            }
            this._current = current;
        }
        this._current++;
        var literal = slice(stream, start + 1, this._current - 1);
        return replace(literal,"\\'", "'","all");
    }

    function _consumeNumber(stream) {
        var start = this._current;
        this._current++;
        var maxLength = stream.len();
        while (this._current <= maxLength && isNum(stream[this._current]) ) {
            this._current++;
        }
        var value = parseNumber(slice(stream, start, this._current));
        return {type: TOK_NUMBER, value: value, start: start};
    }

    function _consumeLBracket(stream) {
        var start = this._current;
        this._current++;
        if (stream[this._current] == '?') {
            this._current++;
            return {type: TOK_FILTER, value: '[?', start: start};
        } else if (stream[this._current] == ']') {
            this._current++;
            return {type: TOK_FLATTEN, value: '[]', start: start};
        } else {
            return {type: TOK_LBRACKET, value: '[', start: start};
        }
    }

    function _consumeOperator(stream) {
        var start = this._current;
        var startingChar = stream[start];
        var maxLength = stream.len()
        this._current++;
        if (startingChar == '!') {
            if (this._current <= maxLength && stream[this._current] == '=') {
                this._current++;
                return {type: TOK_NE, value: '!=', start: start};
            } else {
                return {type: TOK_NOT, value: '!', start: start};
            }
        } else if (startingChar == '<') {
            if (this._current <= maxLength && stream[this._current] == '=') {
                this._current++;
                return {type: TOK_LTE, value: '<=', start: start};
            } else {
                return {type: TOK_LT, value: '<', start: start};
            }
        } else if (startingChar == '>') {
            if (this._current <= maxLength && stream[this._current] == '=') {
                this._current++;
                return {type: TOK_GTE, value: '>=', start: start};
            } else {
                return {type: TOK_GT, value: '>', start: start};
            }
        } else if (startingChar == '=') {
            if (this._current <= maxLength && stream[this._current] == '=') {
                this._current++;
                return {type: TOK_EQ, value: '==', start: start};
            }
        }
    }

    function _consumeLiteral(stream) {
        this._current++;
        var start = this._current;
        var maxLength = stream.len();
        var literal;
        while (this._current <= maxLength && stream[this._current] != '`') {
            // You can escape a literal char or you can escape the escape.
            current = this._current;
            if (
                stream[current] == '\' && (
                    stream[current + 1] == '\' ||
                    stream[current + 1] == '`'
                )
            ) {
                current += 2;
            } else {
                current++;
            }
            this._current = current;
        }
        literalString = lTrim(slice(stream, start, this._current));
        literalString = replace(literalString,'\`', '`', 'all');

        
        if (this._looksLikeJSON(literalString)) {
            literal = parseJson(literalString);
        } else {
            // Try to deserializeJSON it as "<literal>"
            literal = parseJson("'" & literalString & "'");
            //literal = parseJson(literal);
        }
        if(isSimpleValue(literal)){
            literal = parseJson(literal);
        }
        // +1 gets us to the ending "`", +1 to move on to the next char.
        this._current++;
        return literal;
    }

    function _looksLikeJSON(literalString) {
        var startingChars = '[{';
        var jsonLiterals = ['true', 'false', 'null'];
        var numberLooking = '-0123456789';
        /*var valCheck = {
            _: literalString,
            first: literalString[1],
            empty: literalString == '',
            arrayNotation: find(literalString[1], startingChars),
            literals: arrayFind(jsonLiterals, literalString),
            numbers: find(literalString[1],numberLooking)
        };
        dump(valCheck);*/
        if (literalString == '') {
            return false;
        } else if (find(literalString[1],startingChars) > 0) {
            return true;
        } else if (arrayFind(jsonLiterals, literalString) > 0) {
            return true;
        } else if (find(literalString[1], numberLooking) > 0) {
            try {
                deserializeJSON(literalString);
                return true;
            } catch (any e) {
                return false;
            }
        } else {
            return false;
        }
    }

    /**
     * Parses a JSON token or sets the token type to "unknown" on error.
     *
     * @param array $token Token that needs parsing.
     *
     * @return array Returns a token with a parsed value.
     */
    private function parseJson(token) {
        try {
            value = deserializeJSON(token);
        } catch (any e) {
            //echo(token & " -> Error: " & e.message & "<br/>");
            //return token;
            try {
                value = deserializeJSON('"' & token & '"');
            } catch (any f) {
                //echo(token & " -> Error: " & f.message & "<br/>");
               return token;
            }
        }
        return value
    }

}

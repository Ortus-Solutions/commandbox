component singleton  displayname="Parser" {
	property name="jmesPathLexer" inject="Lexer@JMESPath";

    TOK_EOF = 'EOF';
    TOK_UNQUOTEDIDENTIFIER = 'UnquotedIdentifier';
    TOK_QUOTEDIDENTIFIER = 'QuotedIdentifier';
    TOK_RBRACKET = 'Rbracket';
    TOK_RPAREN = 'Rparen';
    TOK_COMMA = 'Comma';
    TOK_COLON = 'Colon';
    TOK_RBRACE = 'Rbrace';
    TOK_NUMBER = 'Number';
    TOK_CURRENT = 'Current';
    TOK_EXPREF = 'Expref';
    TOK_PIPE = 'Pipe';
    TOK_OR = 'Or';
    TOK_AND = 'And';
    TOK_EQ = 'EQ';
    TOK_GT = 'GT';
    TOK_LT = 'LT';
    TOK_GTE = 'GTE';
    TOK_LTE = 'LTE';
    TOK_NE = 'NE';
    TOK_FLATTEN = 'Flatten';
    TOK_STAR = 'Star';
    TOK_FILTER = 'Filter';
    TOK_DOT = 'Dot';
    TOK_NOT = 'Not';
    TOK_LBRACE = 'Lbrace';
    TOK_LBRACKET = 'Lbracket';
    TOK_LPAREN = 'Lparen';
    TOK_LITERAL = 'Literal';

    bindingPower = {};
    bindingPower[TOK_EOF] = 0;
    bindingPower[TOK_UNQUOTEDIDENTIFIER] = 0;
    bindingPower[TOK_QUOTEDIDENTIFIER] = 0;
    bindingPower[TOK_RBRACKET] = 0;
    bindingPower[TOK_RPAREN] = 0;
    bindingPower[TOK_COMMA] = 0;
    bindingPower[TOK_RBRACE] = 0;
    bindingPower[TOK_NUMBER] = 0;
    bindingPower[TOK_CURRENT] = 0;
    bindingPower[TOK_EXPREF] = 0;
    bindingPower[TOK_PIPE] = 1;
    bindingPower[TOK_OR] = 2;
    bindingPower[TOK_AND] = 3;
    bindingPower[TOK_EQ] = 5;
    bindingPower[TOK_GT] = 5;
    bindingPower[TOK_LT] = 5;
    bindingPower[TOK_GTE] = 5;
    bindingPower[TOK_LTE] = 5;
    bindingPower[TOK_NE] = 5;
    bindingPower[TOK_FLATTEN] = 9;
    bindingPower[TOK_STAR] = 20;
    bindingPower[TOK_FILTER] = 21;
    bindingPower[TOK_DOT] = 40;
    bindingPower[TOK_NOT] = 45;
    bindingPower[TOK_LBRACE] = 50;
    bindingPower[TOK_LBRACKET] = 55;
    bindingPower[TOK_LPAREN] = 60;


    function parse(expression) {
        var state = {
            tokens: _loadTokens(expression),
            index: 1
        }

        var ast = this.expression(0,state);
        if (this._lookahead(0,state) != TOK_EOF) {
            var t = this._lookaheadToken(0,state);
            throw( message= 'Unexpected token type', type="JSONException", detail= 'Unexpected token type: ' & t.type & ', value: ' & t.value);
        }
        return ast;
    }

    function _loadTokens(expression) {
        var tokens = jmesPathLexer.tokenize(expression);
        tokens.append({type: TOK_EOF, value: '', start: expression.len()});
        return tokens;
    }

    function expression(rbp, state) {
        var leftToken = this._lookaheadToken(0,state);
        this._advance(state);
        var left = this.nud(leftToken, state);
        var currentToken = this._lookahead(0,state);
        while (rbp < bindingPower[currentToken]) {
            this._advance(state);
            left = this.led(currentToken, left, state);
            currentToken = this._lookahead(0,state);
        }
        return left;
    }

    function _lookahead(number, state) {
        return state.tokens[state.index + number].type;
    }

    function _lookaheadToken(number, state) {
        return state.tokens[state.index + number];
    }

    function _advance(state) {
        state.index++;
    }

    function nud(token, state) {
        var left;
        var right;
        var expression;
        switch (token.type) {
            case TOK_LITERAL:
                return {type: 'Literal', value: token.value};
            case TOK_UNQUOTEDIDENTIFIER:
                return {type: 'Field', name: token.value};
            case TOK_QUOTEDIDENTIFIER:
                var node = {type: 'Field', name: token.value};
                if (this._lookahead(0,state) == TOK_LPAREN) {
                    throw( type="JSONException", message='Quoted identifier not allowed for function names.');
                }
                return node;
            case TOK_NOT:
                right = this.expression(bindingPower.Not, state);
                return {type: 'NotExpression', children: [right]};
            case TOK_STAR:
                left = {type: 'Identity'};
                right = nullvalue();
                if (this._lookahead(0,state) == TOK_RBRACKET) {
                    // This can happen in a multiselect,
                    // [a, b, *]
                    right = {type: 'Identity'};
                } else {
                    right = this._parseProjectionRHS(bindingPower.Star, state);
                }
                return {type: 'ValueProjection', children: [left, right]};
            case TOK_FILTER:
                return this.led(token.type, {type: 'Identity'}, state);
            case TOK_LBRACE:
                return this._parseMultiselectHash(state);
            case TOK_FLATTEN:
                left = {type: TOK_FLATTEN, children: [{type: 'Identity'}]};
                right = this._parseProjectionRHS(bindingPower.Flatten, state);
                return {type: 'Projection', children: [left, right]};
            case TOK_LBRACKET:
                if (this._lookahead(0,state) == TOK_NUMBER || this._lookahead(0,state) == TOK_COLON) {
                    right = this._parseIndexExpression(state);
                    return this._projectIfSlice({type: 'Identity'}, right, state);
                } else if (
                    this._lookahead(0,state) == TOK_STAR &&
                    this._lookahead(1,state) == TOK_RBRACKET
                ) {
                    this._advance(state);
                    this._advance(state);
                    right = this._parseProjectionRHS(bindingPower.Star, state);
                    return {type: 'Projection', children: [{type: 'Identity'}, right]};
                }
                return this._parseMultiselectList(state);
            case TOK_CURRENT:
                return {type: TOK_CURRENT};
            case TOK_EXPREF:
                expression = this.expression(bindingPower.Expref, state);
                return {type: 'ExpressionReference', children: [expression]};
            case TOK_LPAREN:
                var args = [];
                while (this._lookahead(0,state) != TOK_RPAREN) {
                    if (this._lookahead(0,state) == TOK_CURRENT) {
                        expression = {type: TOK_CURRENT};
                        this._advance(state);
                    } else {
                        expression = this.expression(0,state);
                    }
                    args.append(expression);
                }
                this._match(TOK_RPAREN,state);
                return args[1];
            default:
                this._errorToken(token, state);
        }
    }
    function led(tokenName, left, state) {
        var right;
        switch (tokenName) {
            case TOK_DOT:
                var rbp = bindingPower.Dot;
                if (this._lookahead(0,state) != TOK_STAR) {
                    right = this._parseDotRHS(rbp, state);
                    return {type: 'Subexpression', children: [left, right]};
                }
                // Creating a projection.
                this._advance(state);
                right = this._parseProjectionRHS(rbp, state);
                return {type: 'ValueProjection', children: [left, right]};
            case TOK_PIPE:
                right = this.expression(bindingPower.Pipe, state);
                return {type: TOK_PIPE, children: [left, right]};
            case TOK_OR:
                right = this.expression(bindingPower.Or, state);
                return {type: 'OrExpression', children: [left, right]};
            case TOK_AND:
                right = this.expression(bindingPower.And, state);
                return {type: 'AndExpression', children: [left, right]};
            case TOK_LPAREN:
                var name = left.name;
                var args = [];
                var expression;
                var node;
                while (this._lookahead(0,state) != TOK_RPAREN) {
                    if (this._lookahead(0,state) == TOK_CURRENT) {
                        expression = {type: TOK_CURRENT};
                        this._advance(state);
                    } else {
                        expression = this.expression(0,state);
                    }
                    if (this._lookahead(0,state) == TOK_COMMA) {
                        this._match(TOK_COMMA,state);
                    }
                    args.append(expression);
                }
                this._match(TOK_RPAREN,state);
                node = {type: 'Function', name: name, children: args};
                return node;
            case TOK_FILTER:
                var condition = this.expression(0,state);
                this._match(TOK_RBRACKET,state);
                if (this._lookahead(0,state) == TOK_FLATTEN) {
                    right = {type: 'Identity'};
                } else {
                    right = this._parseProjectionRHS(bindingPower.Filter, state);
                }
                return {type: 'FilterProjection', children: [left, right, condition]};
            case TOK_FLATTEN:
                var leftNode = {type: TOK_FLATTEN, children: [left]};
                var rightNode = this._parseProjectionRHS(bindingPower.Flatten, state);
                return {type: 'Projection', children: [leftNode, rightNode]};
            case TOK_EQ:
            case TOK_NE:
            case TOK_GT:
            case TOK_GTE:
            case TOK_LT:
            case TOK_LTE:
                return this._parseComparator(left, tokenName, state);
            case TOK_LBRACKET:
                var token = this._lookaheadToken(0,state);
                if (token.type == TOK_NUMBER || token.type == TOK_COLON) {
                    right = this._parseIndexExpression(state);
                    return this._projectIfSlice(left, right, state);
                }
                this._match(TOK_STAR,state);
                this._match(TOK_RBRACKET,state);
                right = this._parseProjectionRHS(bindingPower.Star, state);
                return {type: 'Projection', children: [left, right]};
            default:
                this._errorToken(this._lookaheadToken(0,state), state);
        }
    }
    function _match(tokenType,state) {
        if (this._lookahead(0,state) == tokenType) {
            this._advance(state);
        } else {
            var t = this._lookaheadToken(0,state);
            //dump(t)
            throw( type="JSONException", message='Expected ' & tokenType & ', got: ' & t.type);
        }
    }
    function _errorToken(token, state) {
        throw( type="JSONException", message= 'Invalid token (' & token.type & '): "' & token.value & '"' );
    }
    function _parseIndexExpression(state) {
        if (this._lookahead(0,state) == TOK_COLON || this._lookahead(1,state) == TOK_COLON) {
            return this._parseSliceExpression(state);
        } else {
            var node = {type: 'Index', value: this._lookaheadToken(0,state).value};
            this._advance(state);
            this._match(TOK_RBRACKET,state);
            return node;
        }
    }
    function _projectIfSlice(left, right, state) {
        var indexExpr = {type: 'IndexExpression', children: [left, right]};
        if (right.type == 'Slice') {
            return {type: 'Projection', children: [indexExpr, this._parseProjectionRHS(bindingPower.Star, state)]};
        } else {
            return indexExpr;
        }
    }
    function _parseSliceExpression(state) {
        // [start:end:step] where each part is optional, as well as the last
        // colon.
        var parts = [nullvalue(), nullvalue(), nullvalue()];
        var index = 1;
        var currentToken = this._lookahead(0,state);
        while (currentToken != TOK_RBRACKET && index <= 3) {
            if (currentToken == TOK_COLON) {
                index++;
                this._advance(state);
            } else if (currentToken == TOK_NUMBER) {
                parts[index] = this._lookaheadToken(0,state).value;
                this._advance(state);
            } else {
                var t = this._lookahead(0,state);
                throw( type="JSONException", message= 'Parser Error: Syntax error, unexpected token: ' &  t.value & '(' & t.type & ')');
            }
            currentToken = this._lookahead(0,state);
        }
        this._match(TOK_RBRACKET,state);
        return {type: 'Slice', children: parts};
    }
    function _parseComparator(left, comparator, state) {
        var right = this.expression(bindingPower[comparator], state);
        return {type: 'Comparator', name: comparator, children: [left, right]};
    }
    function _parseDotRHS(rbp, state) {
        var lookahead = this._lookahead(0,state);
        var exprTokens = [TOK_UNQUOTEDIDENTIFIER, TOK_QUOTEDIDENTIFIER, TOK_STAR];
        if (exprTokens.indexOf(lookahead) >= 0) {
            return this.expression(rbp, state);
        } else if (lookahead == TOK_LBRACKET) {
            this._match(TOK_LBRACKET,state);
            return this._parseMultiselectList(state);
        } else if (lookahead == TOK_LBRACE) {
            this._match(TOK_LBRACE,state);
            return this._parseMultiselectHash(state);
        }
    }
    function _parseProjectionRHS(rbp, state) {
        var right;
        if (bindingPower[this._lookahead(0,state)] < 10) {
            right = {type: 'Identity'};
        } else if (this._lookahead(0,state) == TOK_LBRACKET) {
            right = this.expression(rbp, state);
        } else if (this._lookahead(0,state) == TOK_FILTER) {
            right = this.expression(rbp, state);
        } else if (this._lookahead(0,state) == TOK_DOT) {
            this._match(TOK_DOT,state);
            right = this._parseDotRHS(rbp, state);
        } else {
            var t = this._lookaheadToken(0,state);
            throw(type="JSONException", message= 'ParserError: Sytanx error, unexpected token: ' & t.value & '(' & t.type & ')' );
        }
        return right;
    }
    function _parseMultiselectList(state) {
        var expressions = [];
        while (this._lookahead(0,state) != TOK_RBRACKET) {
            var expression = this.expression(0,state);
            expressions.append(expression);
            if (this._lookahead(0,state) == TOK_COMMA) {
                this._match(TOK_COMMA,state);
                if (this._lookahead(0,state) == TOK_RBRACKET) {
                    throw(type="JSONException", message= 'Unexpected token Rbracket');
                }
            }
        }
        this._match(TOK_RBRACKET,state);
        return {type: 'MultiSelectList', children: expressions};
    }
    function _parseMultiselectHash(state) {
        var pairs = [];
        var identifierTypes = [TOK_UNQUOTEDIDENTIFIER, TOK_QUOTEDIDENTIFIER];
        var keyToken;
        var keyName;
        var value;
        var node;
        for (; ;) {
            keyToken = this._lookaheadToken(0,state);
            if (identifierTypes.indexOf(keyToken.type) < 0) {
                throw(type="JSONException", message= 'Expecting an identifier token, got: ' & keyToken.type);
            }
            keyName = keyToken.value;
            this._advance(state);
            this._match(TOK_COLON,state);
            value = this.expression(0,state);
            node = {type: 'KeyValuePair', name: keyName, value: value};
            pairs.append(node);
            if (this._lookahead(0,state) == TOK_COMMA) {
                this._match(TOK_COMMA,state);
            } else if (this._lookahead(0,state) == TOK_RBRACE) {
                this._match(TOK_RBRACE,state);
                break;
            }
        }
        return {type: 'MultiSelectHash', children: pairs};
    }

}

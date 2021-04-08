component displayname="Parser" {

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

    variables.bindingPower = {};
    variables.bindingPower[TOK_EOF] = 0;
    variables.bindingPower[TOK_UNQUOTEDIDENTIFIER] = 0;
    variables.bindingPower[TOK_QUOTEDIDENTIFIER] = 0;
    variables.bindingPower[TOK_RBRACKET] = 0;
    variables.bindingPower[TOK_RPAREN] = 0;
    variables.bindingPower[TOK_COMMA] = 0;
    variables.bindingPower[TOK_RBRACE] = 0;
    variables.bindingPower[TOK_NUMBER] = 0;
    variables.bindingPower[TOK_CURRENT] = 0;
    variables.bindingPower[TOK_EXPREF] = 0;
    variables.bindingPower[TOK_PIPE] = 1;
    variables.bindingPower[TOK_OR] = 2;
    variables.bindingPower[TOK_AND] = 3;
    variables.bindingPower[TOK_EQ] = 5;
    variables.bindingPower[TOK_GT] = 5;
    variables.bindingPower[TOK_LT] = 5;
    variables.bindingPower[TOK_GTE] = 5;
    variables.bindingPower[TOK_LTE] = 5;
    variables.bindingPower[TOK_NE] = 5;
    variables.bindingPower[TOK_FLATTEN] = 9;
    variables.bindingPower[TOK_STAR] = 20;
    variables.bindingPower[TOK_FILTER] = 21;
    variables.bindingPower[TOK_DOT] = 40;
    variables.bindingPower[TOK_NOT] = 45;
    variables.bindingPower[TOK_LBRACE] = 50;
    variables.bindingPower[TOK_LBRACKET] = 55;
    variables.bindingPower[TOK_LPAREN] = 60;


    function parse(expression) {
        this._loadTokens(expression);
        this.index = 1;
        var ast = this.expression(0);
        if (this._lookahead(0) != TOK_EOF) {
            var t = this._lookaheadToken(0);
            throw( message= 'Unexpected token type', type="JMESError", detail= 'Unexpected token type: ' & t.type & ', value: ' & t.value);
        }
        return ast;
    }
    function _loadTokens(expression) {
        if(!APPLICATION.keyExists("jmesPathLexer"))  APPLICATION.jmesPathLexer = new Lexer();
        var tokens = APPLICATION.jmesPathLexer.tokenize(expression);
        tokens.append({type: TOK_EOF, value: '', start: expression.len()});
        this.tokens = tokens;
    }
    function expression(rbp) {
        var leftToken = this._lookaheadToken(0);
        this._advance();
        var left = this.nud(leftToken);
        var currentToken = this._lookahead(0);
        while (rbp < bindingPower[currentToken]) {
            this._advance();
            left = this.led(currentToken, left);
            currentToken = this._lookahead(0);
        }
        return left;
    }
    function _lookahead(number) {
        return this.tokens[this.index + number].type;
    }
    function _lookaheadToken(number) {
        return this.tokens[this.index + number];
    }
    function _advance() {
        this.index++;
    }
    function nud(token) {
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
                if (this._lookahead(0) == TOK_LPAREN) {
                    throw( type="JMESError", message='Quoted identifier not allowed for function names.');
                }
                return node;
            case TOK_NOT:
                right = this.expression(bindingPower.Not);
                return {type: 'NotExpression', children: [right]};
            case TOK_STAR:
                left = {type: 'Identity'};
                right = nullvalue();
                if (this._lookahead(0) == TOK_RBRACKET) {
                    // This can happen in a multiselect,
                    // [a, b, *]
                    right = {type: 'Identity'};
                } else {
                    right = this._parseProjectionRHS(bindingPower.Star);
                }
                return {type: 'ValueProjection', children: [left, right]};
            case TOK_FILTER:
                return this.led(token.type, {type: 'Identity'});
            case TOK_LBRACE:
                return this._parseMultiselectHash();
            case TOK_FLATTEN:
                left = {type: TOK_FLATTEN, children: [{type: 'Identity'}]};
                right = this._parseProjectionRHS(bindingPower.Flatten);
                return {type: 'Projection', children: [left, right]};
            case TOK_LBRACKET:
                if (this._lookahead(0) == TOK_NUMBER || this._lookahead(0) == TOK_COLON) {
                    right = this._parseIndexExpression();
                    return this._projectIfSlice({type: 'Identity'}, right);
                } else if (
                    this._lookahead(0) == TOK_STAR &&
                    this._lookahead(1) == TOK_RBRACKET
                ) {
                    this._advance();
                    this._advance();
                    right = this._parseProjectionRHS(bindingPower.Star);
                    return {type: 'Projection', children: [{type: 'Identity'}, right]};
                }
                return this._parseMultiselectList();
            case TOK_CURRENT:
                return {type: TOK_CURRENT};
            case TOK_EXPREF:
                expression = this.expression(bindingPower.Expref);
                return {type: 'ExpressionReference', children: [expression]};
            case TOK_LPAREN:
                var args = [];
                while (this._lookahead(0) != TOK_RPAREN) {
                    if (this._lookahead(0) == TOK_CURRENT) {
                        expression = {type: TOK_CURRENT};
                        this._advance();
                    } else {
                        expression = this.expression(0);
                    }
                    args.append(expression);
                }
                this._match(TOK_RPAREN);
                return args[1];
            default:
                this._errorToken(token);
        }
    }
    function led(tokenName, left) {
        var right;
        switch (tokenName) {
            case TOK_DOT:
                var rbp = bindingPower.Dot;
                if (this._lookahead(0) != TOK_STAR) {
                    right = this._parseDotRHS(rbp);
                    return {type: 'Subexpression', children: [left, right]};
                }
                // Creating a projection.
                this._advance();
                right = this._parseProjectionRHS(rbp);
                return {type: 'ValueProjection', children: [left, right]};
            case TOK_PIPE:
                right = this.expression(bindingPower.Pipe);
                return {type: TOK_PIPE, children: [left, right]};
            case TOK_OR:
                right = this.expression(bindingPower.Or);
                return {type: 'OrExpression', children: [left, right]};
            case TOK_AND:
                right = this.expression(bindingPower.And);
                return {type: 'AndExpression', children: [left, right]};
            case TOK_LPAREN:
                var name = left.name;
                var args = [];
                var expression;
                var node;
                while (this._lookahead(0) != TOK_RPAREN) {
                    if (this._lookahead(0) == TOK_CURRENT) {
                        expression = {type: TOK_CURRENT};
                        this._advance();
                    } else {
                        expression = this.expression(0);
                    }
                    if (this._lookahead(0) == TOK_COMMA) {
                        this._match(TOK_COMMA);
                    }
                    args.append(expression);
                }
                this._match(TOK_RPAREN);
                node = {type: 'Function', name: name, children: args};
                return node;
            case TOK_FILTER:
                var condition = this.expression(0);
                this._match(TOK_RBRACKET);
                if (this._lookahead(0) == TOK_FLATTEN) {
                    right = {type: 'Identity'};
                } else {
                    right = this._parseProjectionRHS(bindingPower.Filter);
                }
                return {type: 'FilterProjection', children: [left, right, condition]};
            case TOK_FLATTEN:
                var leftNode = {type: TOK_FLATTEN, children: [left]};
                var rightNode = this._parseProjectionRHS(bindingPower.Flatten);
                return {type: 'Projection', children: [leftNode, rightNode]};
            case TOK_EQ:
            case TOK_NE:
            case TOK_GT:
            case TOK_GTE:
            case TOK_LT:
            case TOK_LTE:
                return this._parseComparator(left, tokenName);
            case TOK_LBRACKET:
                var token = this._lookaheadToken(0);
                if (token.type == TOK_NUMBER || token.type == TOK_COLON) {
                    right = this._parseIndexExpression();
                    return this._projectIfSlice(left, right);
                }
                this._match(TOK_STAR);
                this._match(TOK_RBRACKET);
                right = this._parseProjectionRHS(bindingPower.Star);
                return {type: 'Projection', children: [left, right]};
            default:
                this._errorToken(this._lookaheadToken(0));
        }
    }
    function _match(tokenType) {
        if (this._lookahead(0) == tokenType) {
            this._advance();
        } else {
            var t = this._lookaheadToken(0);
            //dump(t)
            throw( type="JMESError", message='Expected ' & tokenType & ', got: ' & t.type);
        }
    }
    function _errorToken(token) {
         throw( type="JMESError", message= 'Invalid token (' & token.type & '): "' & token.value & '"' );
    }
    function _parseIndexExpression() {
        if (this._lookahead(0) == TOK_COLON || this._lookahead(1) == TOK_COLON) {
            return this._parseSliceExpression();
        } else {
            var node = {type: 'Index', value: this._lookaheadToken(0).value};
            this._advance();
            this._match(TOK_RBRACKET);
            return node;
        }
    }
    function _projectIfSlice(left, right) {
        var indexExpr = {type: 'IndexExpression', children: [left, right]};
        if (right.type == 'Slice') {
            return {type: 'Projection', children: [indexExpr, this._parseProjectionRHS(bindingPower.Star)]};
        } else {
            return indexExpr;
        }
    }
    function _parseSliceExpression() {
        // [start:end:step] where each part is optional, as well as the last
        // colon.
        var parts = [nullvalue(), nullvalue(), nullvalue()];
        var index = 1;
        var currentToken = this._lookahead(0);
        while (currentToken != TOK_RBRACKET && index <= 3) {
            if (currentToken == TOK_COLON) {
                index++;
                this._advance();
            } else if (currentToken == TOK_NUMBER) {
                parts[index] = this._lookaheadToken(0).value;
                this._advance();
            } else {
                var t = this._lookahead(0);
                throw( type="JMESError", message= 'Parser Error: Syntax error, unexpected token: ' &  t.value & '(' & t.type & ')');
            }
            currentToken = this._lookahead(0);
        }
        this._match(TOK_RBRACKET);
        return {type: 'Slice', children: parts};
    }
    function _parseComparator(left, comparator) {
        var right = this.expression(bindingPower[comparator]);
        return {type: 'Comparator', name: comparator, children: [left, right]};
    }
    function _parseDotRHS(rbp) {
        var lookahead = this._lookahead(0);
        var exprTokens = [TOK_UNQUOTEDIDENTIFIER, TOK_QUOTEDIDENTIFIER, TOK_STAR];
        if (exprTokens.indexOf(lookahead) >= 0) {
            return this.expression(rbp);
        } else if (lookahead == TOK_LBRACKET) {
            this._match(TOK_LBRACKET);
            return this._parseMultiselectList();
        } else if (lookahead == TOK_LBRACE) {
            this._match(TOK_LBRACE);
            return this._parseMultiselectHash();
        }
    }
    function _parseProjectionRHS(rbp) {
        var right;
        if (bindingPower[this._lookahead(0)] < 10) {
            right = {type: 'Identity'};
        } else if (this._lookahead(0) == TOK_LBRACKET) {
            right = this.expression(rbp);
        } else if (this._lookahead(0) == TOK_FILTER) {
            right = this.expression(rbp);
        } else if (this._lookahead(0) == TOK_DOT) {
            this._match(TOK_DOT);
            right = this._parseDotRHS(rbp);
        } else {
            var t = this._lookaheadToken(0);
            throw(type="JMESError", message= 'ParserError: Sytanx error, unexpected token: ' & t.value & '(' & t.type & ')' );
        }
        return right;
    }
    function _parseMultiselectList() {
        var expressions = [];
        while (this._lookahead(0) != TOK_RBRACKET) {
            var expression = this.expression(0);
            expressions.append(expression);
            if (this._lookahead(0) == TOK_COMMA) {
                this._match(TOK_COMMA);
                if (this._lookahead(0) == TOK_RBRACKET) {
                    throw(type="JMESError", message= 'Unexpected token Rbracket');
                }
            }
        }
        this._match(TOK_RBRACKET);
        return {type: 'MultiSelectList', children: expressions};
    }
    function _parseMultiselectHash() {
        var pairs = [];
        var identifierTypes = [TOK_UNQUOTEDIDENTIFIER, TOK_QUOTEDIDENTIFIER];
        var keyToken;
        var keyName;
        var value;
        var node;
        for (; ;) {
            keyToken = this._lookaheadToken(0);
            if (identifierTypes.indexOf(keyToken.type) < 0) {
                throw(type="JMESError", message= 'Expecting an identifier token, got: ' & keyToken.type);
            }
            keyName = keyToken.value;
            this._advance();
            this._match(TOK_COLON);
            value = this.expression(0);
            node = {type: 'KeyValuePair', name: keyName, value: value};
            pairs.append(node);
            if (this._lookahead(0) == TOK_COMMA) {
                this._match(TOK_COMMA);
            } else if (this._lookahead(0) == TOK_RBRACE) {
                this._match(TOK_RBRACE);
                break;
            }
        }
        return {type: 'MultiSelectHash', children: pairs};
    }

}

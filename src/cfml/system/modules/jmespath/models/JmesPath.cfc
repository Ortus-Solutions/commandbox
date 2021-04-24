component singleton {
	property name="jmesPathLexer" inject="Lexer@JMESPath";
	property name="jmesPathParser" inject="Parser@JMESPath";
	property name="jmesPathRuntime" inject="Runtime@JMESPath";
	property name="jmesPathTreeInterpreter" inject="TreeInterpreter@JMESPath";

    function compile(stream) {
        var ast = jmesPathParser.parse(stream);
        return ast;
    }
    function tokenize(stream) {
        return jmesPathLexer.tokenize(stream);
    }
    function search(data, expression) {
		var node = jmesPathParser.parse(expression);
        return jmesPathTreeInterpreter.search(node, data);
    }

}

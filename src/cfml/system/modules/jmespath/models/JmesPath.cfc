component {

    function compile(stream) {
        if(!APPLICATION.keyExists("jmespathparser")){
            APPLICATION.jmesPathParser = new Parser();
        }
        var ast = APPLICATION.jmesPathParser.parse(stream);
        return ast;
    }
    function tokenize(stream) {
        if(!APPLICATION.keyExists("jmesPathLexer"))  APPLICATION.jmesPathLexer= new Lexer();
        return APPLICATION.jmesPathLexer.tokenize(stream);
    }
    function search(data, expression) {
        if(!APPLICATION.keyExists("jmesPathParser"))  APPLICATION.jmesPathParser = new Parser();
        if(!APPLICATION.keyExists("jmesPathRuntime"))  APPLICATION.jmesPathRuntime = new Runtime();
        if(!APPLICATION.keyExists("jmesPathTreeInterpreter"))  APPLICATION.jmesPathTreeInterpreter = new TreeInterpreter(APPLICATION.jmesPathRuntime);
        var node = APPLICATION.jmesPathParser.parse(expression);
        return APPLICATION.jmesPathTreeInterpreter.search(node, data);
    }

}

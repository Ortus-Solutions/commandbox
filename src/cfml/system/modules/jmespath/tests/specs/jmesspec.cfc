/**
* This tests the BDD functionality in TestBox. This is CF10+, Lucee4.5+
*/
component extends="testbox.system.BaseSpec"{

/*********************************** LIFE CYCLE Methods ***********************************/

	function beforeAll(){
		jmespath = new models.JmesPath();
		tokenize = jmespath.tokenize;
		compile = jmespath.compile;
		//strictDeepEqual = jmespath.strictDeepEqual;


	}

	function afterAll(){
		structClear( application );
	}

/*********************************** BDD SUITES ***********************************/

	function run(){

		/**
		* describe() starts a suite group of spec tests.
		* Arguments:
		* @title The title of the suite, Usually how you want to name the desired behavior
		* @body A closure that will resemble the tests to execute.
		* @labels The list or array of labels this suite group belongs to
		* @asyncAll If you want to parallelize the execution of the defined specs in this suite group.
		* @skip A flag that tells TestBox to skip this suite group from testing if true
		*/
		describe( "A spec", function(){

			it("is just a closure so it can contain code", function(){
				    origJSON = {"foo": [{"age": 20}, {"age": 25},{"age": 30}, {"age": 35},{"age": 40}]};
					searchStr = "foo[?age > `30`]";
					result = jmespath.search(origJSON,searchStr);
					expResult = [{"age":35},{"age":40}];
					expect( result ).toBe( expResult );
			});

	
		});


		describe('tokenize', function() {
			it('should tokenize unquoted identifier', function() {
				expect(tokenize('foo')).toBe(
								[{type: "UnquotedIdentifier",
								value: "foo",
								start: 1}]);
			});
			it('should tokenize unquoted identifier with underscore', function() {
				expect(tokenize('_underscore')).toBe(
								[{type: "UnquotedIdentifier",
								value: "_underscore",
								start: 1}]);
			});
			it('should tokenize unquoted identifier with numbers', function() {
				expect(tokenize('foo123')).toBe(
								[{type: "UnquotedIdentifier",
								value: "foo123",
								start: 1}]);
			});
			it('should tokenize dotted lookups', function() {
				expect(
					tokenize('foo.bar')).toBe(
					[{type: "UnquotedIdentifier", value: "foo", start: 1},
					{type: "Dot", value: ".", start: 4},
					{type: "UnquotedIdentifier", value: "bar", start: 5},
					]);
			});
			it('should tokenize numbers', function() {
				expect(
					tokenize('foo[0]')).toBe(
					[{type: "UnquotedIdentifier", value: "foo", start: 1},
					{type: "Lbracket", value: "[", start: 4},
					{type: "Number", value: 0, start: 5},
					{type: "Rbracket", value: "]", start: 6},
					]);
			});
			it('should tokenize numbers with multiple digits', function() {
				expect(
					tokenize("12345")).toBe(
					[{type: "Number", value: 12345, start: 1}]);
			});
			it('should tokenize negative numbers', function() {
				expect(
					tokenize("-12345")).toBe(
					[{type: "Number", value: -12345, start: 1}]);
			});
			it('should tokenize quoted identifier', function() {
				expect(tokenize('"foo"')).toBe(
								[{type: "QuotedIdentifier",
								value: "foo",
								start: 1}]);
			});
			it('should tokenize quoted identifier with unicode escape', function() {
				expect(tokenize('"\\u2713"')).toBe(
								[{type: "QuotedIdentifier",
								value: "✓",
								start: 1}]);
			});
			it('should tokenize literal lists', function() {
				expect(tokenize("`[0, 1]`")).toBe(
								[{type: "Literal",
								value: [0, 1],
								start: 1}]);
			});
			it('should tokenize literal dict', function() {
				expect(tokenize('`{\"foo\": \"bar\"}`')).toBe(
								[{type: "Literal",
								value: {"foo": "bar"},
								start: 1}]);
			});
			it('should tokenize literal strings', function() {
				expect(tokenize('`\"foo\"`')).toBe(
								[{type: "Literal",
								value: "foo",
								start: 1}]);
			});
			it('should tokenize json literals', function() {
				expect(tokenize("`true`")).toBe(
								[{type: "Literal",
								value: true,
								start: 1}]);
			});
			it('should not requiring surrounding quotes for strings', function() {
				expect(tokenize("`foo`")).toBe(
								[{type: "Literal",
								value: "foo",
								start: 1}]);
			});
			it('should not requiring surrounding quotes for numbers', function() {
				expect(tokenize("`20`")).toBe(
								[{type: "Literal",
								value: 20,
								start: 1}]);
			});
			it('should tokenize literal lists with chars afterwards', function() {
				expect(
					tokenize("`[0, 1]`[0]")).toBe( [
						{type: "Literal", value: [0, 1], start: 1},
						{type: "Lbracket", value: "[", start: 9},
						{type: "Number", value: 0, start: 10},
						{type: "Rbracket", value: "]", start: 11}
				]);
			});
			it('should tokenize two char tokens with shared prefix', function() {
				expect(
					tokenize("[?foo]")).toBe(
					[{type: "Filter", value: "[?", start: 1},
					{type: "UnquotedIdentifier", value: "foo", start: 3},
					{type: "Rbracket", value: "]", start: 6}]
				);
			});
			it('should tokenize flatten operator', function() {
				expect(
					tokenize("[]")).toBe(
					[{type: "Flatten", value: "[]", start: 1}]);
			});
			it('should tokenize comparators', function() {
				expect(tokenize("<")).toBe(
								[{type: "LT",
								value: "<",
								start: 1}]);
			});
			it('should tokenize two char tokens without shared prefix', function() {
				expect(
					tokenize("==")).toBe(
					[{type: "EQ", value: "==", start: 1}]
				);
			});
			it('should tokenize not equals', function() {
				expect(
					tokenize("!=")).toBe(
					[{type: "NE", value: "!=", start: 1}]
				);
			});
			it('should tokenize the OR token', function() {
				expect(
					tokenize("a||b")).toBe(
					[
						{type: "UnquotedIdentifier", value: "a", start: 1},
						{type: "Or", value: "||", start: 2},
						{type: "UnquotedIdentifier", value: "b", start: 4}
					]
				);
			});
			it('should tokenize function calls', function() {
				expect(
					tokenize("abs(@)")).toBe(
					[
						{type: "UnquotedIdentifier", value: "abs", start: 1},
						{type: "Lparen", value: "(", start: 4},
						{type: "Current", value: "@", start: 5},
						{type: "Rparen", value: ")", start: 6}
					]
				);
			});

		});


		describe('parsing', function() {
			it('should parse field node', function() {
				expect(compile('foo')).toBe(
								{type: 'Field', name: 'foo'});
			});
		});

		/*describe('start: 1', function() {
			it('should compare scalars', function() {
				expect(strictDeepEqual('a', 'a')).toBe( true);
			});
			it('should be false for different types', function() {
				expect(strictDeepEqual('a', 2)).toBe( false);
			});
			it('should be false for arrays of different lengths', function() {
				expect(strictDeepEqual([0, 1], [1, 2, 3])).toBe( false);
			});
			it('should be true for identical arrays', function() {
				expect(strictDeepEqual([0, 1], [0, 1])).toBe( true);
			});
			it('should be true for nested arrays', function() {
				expect(
					strictDeepEqual([[0, 1], [2, 3]], [[0, 1], [2, 3]])).toBe( true);
			});
			it('should be true for nested arrays of strings', function() {
				expect(
					strictDeepEqual([["a", "b"], ["c", "d"]],
									[["a", "b"], ["c", "d"]])).toBe( true);
			});
			it('should be false for different arrays of the same length', function() {
				expect(strictDeepEqual([0, 1], [1, 2])).toBe( false);
			});
			it('should handle object literals', function() {
				expect(strictDeepEqual({a: 1, b: 2}, {a: 1, b: 2})).toBe(true);
			});
			it('should handle keys in first not in second', function() {
				expect(strictDeepEqual({a: 1, b: 2}, {a: 1})).toBe( false);
			});
			it('should handle keys in second not in first', function() {
				expect(strictDeepEqual({a: 1}, {a: 1, b: 2})).toBe( false);
			});
			it('should handle nested objects', function() {
				expect(
					strictDeepEqual({a: {b: [1, 2]}},
									{a: {b: [1, 2]}})).toBe( true);
			});
			it('should handle nested objects that are not equal', function() {
				expect(
					strictDeepEqual({a: {b: [1, 2]}},
									{a: {b: [1, 4]}})).toBe(false);
			});
		});

		 describe('search', function() {
			it(
				'should throw a readable error when invalid arguments are provided to a function',
				function() {
					try {
						jmespath.search([], 'length(`null`)');
					} catch (e) {
						assert(e.message.search(
							'expected argument 1 to be type string,array,object'
						), e.message);
						assert(e.message.search('received type null'), e.message);
					}
				}
			);
		}); */



	}


}
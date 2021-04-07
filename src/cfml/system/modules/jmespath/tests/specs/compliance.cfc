/**
* This tests the BDD functionality in TestBox. This is CF10+, Lucee4.5+
*/
component extends="testbox.system.BaseSpec"{

/*********************************** LIFE CYCLE Methods ***********************************/

	function beforeAll(){
		jmespath = new models.JmesPath();
		tokenize = jmespath.tokenize;
		compile = jmespath.compile;
		search = jmespath.search;
		//strictDeepEqual = jmespath.strictDeepEqual;


	}

	function afterAll(){
		structClear( application );
	}

/*********************************** BDD SUITES ***********************************/

	function run(){

        listing = directoryList(expandPath("./resources/"), false, "name,query", "*.json", "file" );
        for (var i = 1; i <= listing.len(); i++) {
            fileContent = fileRead(listing[i], "utf-8");
            filename = getFileFromPath(listing[i]);
            describe("#filename#", function(){

                spec = deserializeJSON(fileContent);
                for (var i = 1; i <=spec.len(); i++) {
                    var msg = "suite " & i & " for filename " & filename;
                    describe(msg, function() {
                        var given = spec[i].given;
                        var cases = spec[i].cases;
                        for (var j = 1; j <= cases.len(); j++) {
                            var testcase = cases[j];
                            if (testcase.keyExists('error')) {
                                // For now just verify that an error is thrown
                                // for error tests.
                                //it('should throw error for test ' & j & " expression: " & testcase.expression & " with query -> " & serializeJSON(given), function() {
                                //    expect(function() {search(given, testcase.expression) }).toThrow();
                                //});
                            } else {
                                it( title= ( testcase.comment ?: '') & ' should pass test ' & j & " expression: " & testcase.expression & " with result -> " & serializeJSON(testcase.result), 
                                    data = { testcase = testcase },
                                    body = function(data) {
                                        var testcase = data.testcase;
                                        expect(search(given, testcase.expression)).toBe(testcase.result);
                                    }
                                );
                            }
                        }
                    });
                }
            });


        }
	}


}
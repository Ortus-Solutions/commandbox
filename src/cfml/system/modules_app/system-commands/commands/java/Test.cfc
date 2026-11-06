/**
 * Compiles and runs the project's Java tests.
 *
 * {code:bash}
 * java test
 * java test testClasses=com.foo.MyTest
 * java test testClasses=com.foo.MyTest#myMethod,com.foo.*
 * java test reportsDirectory=build/test-results --JSON
 * {code}
 *
 * The command resolves the JDK, compiles the main source set and then the test
 * source set, assembles the test classpath from the box.json conventions, and then
 * runs JUnit's own console launcher from that classpath. CommandBox does not
 * provide a test runner; JUnit does the running. Nothing test-specific has to be
 * configured beyond `junit-platform-console-standalone` in `devDependencies`.
 *
 * Exit codes:
 * - 0 all tests passed
 * - 1 a test failed, or the build failed
 * - 3 no tests found (and --failIfNoTests), or a test pattern matched nothing
 * - 4 no test runner found on the test classpath, or the launcher failed to start
 **/
component extends="commandbox.system.BaseCommand" {

	property name="fileSystemUtil" inject="FileSystem";
	property name="tempDir"        inject="tempDir@constants";

	/**
	 * @testClasses Select tests by fully qualified class name: com.foo.MyTest, com.foo.MyTest#myMethod, com.foo.*, com.foo.**, *Test. Comma-delimited, OR'd together.
	 * @testClasses.optionsUDF testClassesComplete
	 * @reportsDirectory Directory for the JUnit XML report. Omit for no report file.
	 * @skipCompile Run against the output that is already on disk
	 * @clean Run `java clean` first, then compile and test
	 * @failIfNoTests Fail when no tests are found. Negate with `--noFailIfNoTests` or `failIfNoTests=false`.
	 * @JSON Return a machine-readable summary: totals, failures, per-test status and durations
	 */
	function run(
		string testClasses="",
		string reportsDirectory="",
		boolean skipCompile=false,
		boolean clean=false,
		boolean failIfNoTests=true,
		boolean JSON=false
	) {
		var dsl = compile();
		var projectRoot = dsl.getProjectRoot();

		if( arguments.clean ) {
			dsl.clean();
		}

		if( !arguments.skipCompile ) {
			// A compile failure is a real error: let it propagate so the normal error
			// handling reports it and finalizes the interactive job the compile started.
			compileSources( dsl );
		} else {
			// Resolving the JDK logs through the interactive job, which needs an
			// active job even when the compile step is skipped.
			var job = dsl.getJob();
			job.start( "Resolve JDK" );
			try {
				dsl.setJavaBinFolder( dsl.findJDKBinDirectory() );
			} finally {
				job.complete();
			}
		}

		var testClassesDirectory = fileSystemUtil.resolvePath( dsl.getTestClassOutputDirectory(), projectRoot );

		// No compiled test classes means the test source set is empty, or a previous
		// compile step was skipped. Report "no tests found" instead of starting a
		// runner that can only fail.
		if( !directoryExists( testClassesDirectory ) ) {
			reportNoTests( arguments, testClassesDirectory );
			return;
		}

		var classPathEntries = buildTestClassPath( dsl, projectRoot );
		var classPathString = classPathEntries.toList( fileSystemUtil.isWindows() ? ";" : ":" );

		// JUnit ships the runner; we only assemble the classpath and invoke it
		var runnerInfo = findRunner( classPathEntries );
		if( !runnerInfo.found ) {
			print.redLine( runnerInfo.message ).toConsole();
			setExitCode( 4 );
			return;
		}

		// Resolve the test selection
		var selection = { "selectors" : [], "unmatched" : [] };
		if( len( trim( arguments.testClasses ) ) ) {
			selection = resolveSelectors( arguments.testClasses, testClassesDirectory );
			if( selection.unmatched.len() ) {
				print.redLine(
					"No compiled test classes matched: #selection.unmatched.toList( ', ' )#. Check the pattern, or run `java test` without testClasses= to run every test."
				).toConsole();
				setExitCode( 3 );
				return;
			}
		}

		// The launcher always writes its XML to a scratch directory we own, so the
		// three per-engine files stay out of the project unless a report was asked for.
		var buildDirectory = tempDir & "java-test-" & createUUID() & "/";
		var summary = { "total" : 0, "passed" : 0, "failed" : 0, "skipped" : 0, "tests" : [] };
		var runnerExitCode = 0;
		directoryCreate( buildDirectory, true );
		try {
			runnerExitCode = runTests(
				dsl = dsl,
				projectRoot = projectRoot,
				classPathString = classPathString,
				runnerJarPath = runnerInfo.jarPath,
				testClassesDirectory = testClassesDirectory,
				selection = selection,
				reportsDirectory = buildDirectory,
				// In JSON mode the runner's progress output would sit in front of the
				// JSON and make it unparseable, so it is discarded.
				quiet = arguments.JSON
			);

			summary = readResults( buildDirectory );
			copyReports( buildDirectory, arguments.reportsDirectory, projectRoot );
		} finally {
			if( directoryExists( buildDirectory ) ) {
				directoryDelete( buildDirectory, true );
			}
		}

		// A non-zero exit with nothing to show for it means the launcher itself
		// failed (bad classpath, no engine) rather than there being no tests.
		if( summary.total == 0 && runnerExitCode != 0 ) {
			print.redLine( "The JUnit console launcher failed before it could run any tests. See its output above." ).toConsole();
			setExitCode( 4 );
			return;
		}

		var statusCode = 0;
		if( summary.failed > 0 ) {
			statusCode = 1;
		} else if( summary.total == 0 && arguments.failIfNoTests ) {
			statusCode = 3;
		}

		if( arguments.JSON ) {
			print.line( {
				"totalTests" : summary.total,
				"passed"     : summary.passed,
				"failed"     : summary.failed,
				"skipped"    : summary.skipped,
				"exitCode"   : statusCode,
				"tests"      : summary.tests
			} );
		} else {
			printTestSummary( summary );
		}

		setExitCode( statusCode );
	}

	/**
	 * Copies the launcher's JUnit XML report to the requested directory.
	 *
	 * The console launcher writes one file per engine; only the Jupiter report is
	 * promoted, under a single stable name so CI gets the same file every run.
	 *
	 * @reportsDirectory The scratch directory the launcher wrote to.
	 * @requestedDirectory The directory the caller asked for, or an empty string.
	 * @projectRoot The resolved project root.
	 * @returns Nothing.
	 */
	private function copyReports(
		required string reportsDirectory,
		required string requestedDirectory,
		required string projectRoot
	) {
		if( !len( trim( arguments.requestedDirectory ) ) || !directoryExists( arguments.reportsDirectory ) ) {
			return;
		}

		var reportFiles = directoryList( arguments.reportsDirectory, false, "path", "*.xml" );
		if( !reportFiles.len() ) {
			return;
		}

		// The Jupiter suite holds the real results; the other engine suites are
		// empty containers. Fall back to the first file when there is no Jupiter one.
		var sourceFile = reportFiles[ 1 ];
		for( var reportFile in reportFiles ) {
			if( getFileFromPath( reportFile ).contains( "jupiter" ) ) {
				sourceFile = reportFile;
				break;
			}
		}

		var destinationDirectory = fileSystemUtil.resolvePath( trim( arguments.requestedDirectory ), arguments.projectRoot );
		if( !directoryExists( destinationDirectory ) ) {
			directoryCreate( destinationDirectory, true );
		}
		fileCopy( sourceFile, destinationDirectory & "/TEST-commandbox.xml" );
	}

	/**
	 * Reports that there were no compiled test classes to run.
	 *
	 * @options The command arguments, so the JSON shape and failIfNoTests are honored.
	 * @testClassesDirectory The missing test class output directory.
	 * @returns Nothing.
	 */
	private function reportNoTests( required struct options, required string testClassesDirectory ) {
		var statusCode = arguments.options.failIfNoTests ? 3 : 0;

		if( arguments.options.JSON ) {
			print.line( {
				"runner"     : "",
				"totalTests" : 0,
				"passed"     : 0,
				"failed"     : 0,
				"skipped"    : 0,
				"exitCode"   : statusCode,
				"tests"      : []
			} );
		} else {
			print.yellowLine(
				"No compiled test classes found in #arguments.testClassesDirectory#. Run `java compile --tests` or `java test` without --skipCompile."
			).toConsole();
		}

		setExitCode( statusCode );
	}

	/**
	 * Compiles the main and test source sets through the DSL without building a JAR.
	 *
	 * @dsl The configured CompileDSL instance.
	 * @returns Nothing.
	 */
	private function compileSources( required any dsl ) {
		arguments.dsl.setCompileTests( true );
		// `java test` compiles and runs tests; it never builds or cleans up the
		// project's JAR output, whatever box.json asks for.
		arguments.dsl.setCreateJar( false );
		arguments.dsl.setFatJarPaths( [] );
		arguments.dsl.setUseJavaDoc( false );
		arguments.dsl.run();
	}

	/**
	 * Assembles the test classpath from the box.json conventions.
	 *
	 * The result is additive, mirroring Gradle: the test class output and test
	 * resources, then the main class output and main resources, then the runtime
	 * dependencies, then the test-only dependencies.
	 *
	 * @dsl The configured CompileDSL instance.
	 * @projectRoot The resolved project root.
	 * @returns An ordered, de-duplicated array of absolute existing classpath entries.
	 */
	private array function buildTestClassPath( required any dsl, required string projectRoot ) {
		var entries = [];
		entries.append( fileSystemUtil.resolvePath( arguments.dsl.getTestClassOutputDirectory(), arguments.projectRoot ) );
		entries.append( arguments.dsl.getTestResourcePaths(), true );
		entries.append( fileSystemUtil.resolvePath( arguments.dsl.getClassOutputDirectory(), arguments.projectRoot ) );
		entries.append( arguments.dsl.getResourcePaths(), true );
		entries.append( arguments.dsl.getClassPaths(), true );
		entries.append( arguments.dsl.getTestClassPaths(), true );

		var resolved = [];
		for( var entry in entries ) {
			if( !isSimpleValue( entry ) || !len( trim( entry ) ) ) {
				continue;
			}
			// A trailing separator on a classpath entry escapes the closing quote of the
			// quoted -cp argument and swallows the following argument, so strip them.
			var resolvedEntry = reReplace(
				fileSystemUtil.resolvePath( trim( entry ), arguments.projectRoot ),
				"[\\/]+$",
				""
			);
			if( !fileExists( resolvedEntry ) && !directoryExists( resolvedEntry ) ) {
				continue;
			}
			if( !resolved.findNoCase( resolvedEntry ) ) {
				resolved.append( resolvedEntry );
			}
		}
		return resolved;
	}

	/**
	 * Finds JUnit's own console launcher on the test classpath.
	 *
	 * The launcher is a compiled `main()` that JUnit ships
	 * (`org.junit.platform.console.ConsoleLauncher`), so CommandBox does not need to
	 * provide a runner: this command only assembles the classpath and invokes it.
	 *
	 * @classPathEntries The assembled test classpath.
	 * @returns A struct with found, jarPath and message.
	 */
	private struct function findRunner( required array classPathEntries ) {
		for( var entry in arguments.classPathEntries ) {
			if( !reFindNoCase( "\.jar$", entry ) ) {
				continue;
			}
			if( reFindNoCase( "^junit-platform-console", getFileFromPath( entry ) ) ) {
				return { "found" : true, "jarPath" : entry, "message" : "" };
			}
		}

		return {
			"found" : false,
			"jarPath" : "",
			"message" : "No test runner found on the test classpath. Add `org.junit.platform:junit-platform-console-standalone` to devDependencies in box.json, then run `install`."
		};
	}

	/**
	 * Turns the testClasses patterns into runner selectors.
	 *
	 * The patterns are matched against the compiled test classes, so a pattern that
	 * matches nothing is reported instead of being silently passed to the runner.
	 * `*` matches within one path segment and `**` crosses segments.
	 *
	 * @patterns The comma-delimited patterns the caller supplied.
	 * @testClassesDirectory The compiled test class output directory.
	 * @returns A struct with selectors and unmatched patterns.
	 */
	private struct function resolveSelectors( required string patterns, required string testClassesDirectory ) {
		var classNames = listTestClassNames( arguments.testClassesDirectory );
		var selectors = [];
		var unmatched = [];

		for( var rawPattern in arguments.patterns.listToArray( "," ) ) {
			var pattern = trim( rawPattern );
			if( !len( pattern ) ) {
				continue;
			}

			var classPattern = pattern;
			var methodName = "";
			var hashCharacter = chr( 35 );
			if( find( hashCharacter, pattern ) ) {
				var hashPosition = find( hashCharacter, pattern );
				classPattern = left( pattern, hashPosition - 1 );
				methodName = mid( pattern, hashPosition + 1, len( pattern ) );
			}

			var matches = matchClassPattern( classNames, classPattern );
			if( !matches.len() ) {
				unmatched.append( pattern );
				continue;
			}
			for( var matchedClass in matches ) {
				selectors.append( {
					"type"  : len( methodName ) ? "method" : "class",
					"value" : len( methodName ) ? matchedClass & chr( 35 ) & methodName : matchedClass
				} );
			}
		}

		return { "selectors" : selectors, "unmatched" : unmatched };
	}

	/**
	 * Completion for `testClasses`, so Tab offers the compiled test classes instead
	 * of nothing. Only class names are offered; a `#method` suffix is typed by hand.
	 *
	 * @paramSoFar The text typed so far.
	 * @passedNamedParameters The named parameters already supplied.
	 * @returns The compiled test class names.
	 */
	array function testClassesComplete( string paramSoFar="", struct passedNamedParameters={} ) {
		var dsl = compile();
		return listTestClassNames(
			fileSystemUtil.resolvePath( dsl.getTestClassOutputDirectory(), dsl.getProjectRoot() )
		);
	}

	/**
	 * Enumerates the fully qualified names of the compiled test classes.
	 *
	 * @testClassesDirectory The compiled test class output directory.
	 * @returns A sorted array of fully qualified class names.
	 */
	private array function listTestClassNames( required string testClassesDirectory ) {
		var classNames = [];
		if( !directoryExists( arguments.testClassesDirectory ) ) {
			return classNames;
		}

		for( var classFile in directoryList( arguments.testClassesDirectory, true, "path", "*.class" ) ) {
			var relativePath = replaceNoCase( classFile, arguments.testClassesDirectory, "" );
			relativePath = replace( relativePath, "\", "/", "all" );
			relativePath = reReplace( relativePath, "^/+", "" );
			relativePath = reReplaceNoCase( relativePath, "\.class$", "" );
			var className = replace( relativePath, "/", ".", "all" );
			// Inner and nested classes are discovered through their outer class.
			if( find( chr( 36 ), className ) ) {
				continue;
			}
			if( className == "module-info" || className == "package-info" ) {
				continue;
			}
			if( className.endsWith( ".module-info" ) || className.endsWith( ".package-info" ) ) {
				continue;
			}
			classNames.append( className );
		}
		classNames.sort( "textnocase" );
		return classNames;
	}

	/**
	 * Matches the compiled test class names against one pattern.
	 *
	 * A pattern with no dot is matched against the simple class name, so `*Test`
	 * is a class-name suffix match in any package.
	 *
	 * @classNames The compiled test class names.
	 * @pattern The class pattern to match.
	 * @returns The matching class names.
	 */
	private array function matchClassPattern( required array classNames, required string pattern ) {
		var matches = [];
		var expression = "^" & patternToRegex( arguments.pattern ) & "$";
		var matchSimpleName = !find( ".", arguments.pattern );

		for( var className in arguments.classNames ) {
			var candidate = matchSimpleName ? listLast( className, "." ) : className;
			if( reFindNoCase( expression, candidate ) ) {
				matches.append( className );
			}
		}
		return matches;
	}

	/**
	 * Translates a test class pattern into a regular expression.
	 *
	 * `*` matches within one path segment, `**` crosses segments, which is the same
	 * distinction Ant, Maven Surefire and Gradle make.
	 *
	 * @pattern The pattern to translate.
	 * @returns A regular expression body, without anchors.
	 */
	private string function patternToRegex( required string pattern ) {
		var expression = "";
		var index = 1;
		var length = arguments.pattern.len();

		while( index <= length ) {
			var character = mid( arguments.pattern, index, 1 );
			if( character == "*" ) {
				if( index < length && mid( arguments.pattern, index + 1, 1 ) == "*" ) {
					if( right( expression, 2 ) == "\." ) {
						// `.**` also matches the parent package itself, so the dot we
						// already emitted has to become part of the optional group.
						expression = left( expression, len( expression ) - 2 ) & "(\..*)?";
					} else {
						expression &= ".*";
					}
					index += 2;
					continue;
				}
				expression &= "[^.]*";
				index++;
				continue;
			}
			if( character == "." ) {
				expression &= "\.";
				index++;
				continue;
			}
			if( find( character, "\^$.|?*+()[]{}" ) ) {
				expression &= "\" & character;
			} else {
				expression &= character;
			}
			index++;
		}

		return expression;
	}

	/**
	 * Runs JUnit's console launcher against the test classpath.
	 *
	 * @dsl The configured CompileDSL instance.
	 * @projectRoot The resolved project root.
	 * @classPathString The test classpath, already joined with the platform separator.
	 * @runnerJarPath The console launcher JAR to run.
	 * @testClassesDirectory The compiled test class output directory.
	 * @selection The resolved selectors.
	 * @reportsDirectory The scratch directory the launcher writes its XML report to.
	 * @quiet Discard the runner's console output so only machine-readable output remains.
	 * @returns The runner process exit code.
	 */
	private numeric function runTests(
		required any dsl,
		required string projectRoot,
		required string classPathString,
		required string runnerJarPath,
		required string testClassesDirectory,
		required struct selection,
		required string reportsDirectory,
		boolean quiet=false
	) {
		var executableSuffix = fileSystemUtil.isWindows() ? ".exe" : "";

		var runnerArgs = [
			"execute",
			"--class-path",
			arguments.classPathString,
			"--reports-dir",
			arguments.reportsDirectory,
			"--details",
			arguments.quiet ? "none" : "summary"
		];

		if( arguments.selection.selectors.len() ) {
			for( var selector in arguments.selection.selectors ) {
				runnerArgs.append(
					( selector.type == "method" ? "--select-method=" : "--select-class=" ) & selector.value
				);
			}
		} else {
			// Scanning only the test output keeps discovery off the dependency JARs
			runnerArgs.append( "--scan-classpath=" & arguments.testClassesDirectory );
		}

		var commandArray = [
			arguments.dsl.getJavaBinFolder() & "java" & executableSuffix,
			"-jar",
			arguments.runnerJarPath
		];
		commandArray.append( runnerArgs, true );

		return runProcess(
			commandArray,
			arguments.projectRoot,
			arguments.quiet,
			arguments.reportsDirectory & "/runner-output.txt"
		);
	}

	/**
	 * Runs an external process with the console attached, and returns its exit code.
	 *
	 * JLine is unbound from the keyboard while the process runs so console input
	 * and output go to the process, the same as the `run` command does.
	 *
	 * @commandArray The command and its arguments.
	 * @workingDirectory The directory to run the process in.
	 * @quiet Discard the process output instead of streaming it to the console.
	 * @discardFile Where to send the output when quiet is on.
	 * @returns The process exit code.
	 */
	private numeric function runProcess(
		required array commandArray,
		required string workingDirectory,
		boolean quiet=false,
		string discardFile=""
	) {
		var terminal = shell.getReader().getTerminal();
		terminal.pause();
		try {
			var processBuilder = createObject( "java", "java.lang.ProcessBuilder" ).init( arguments.commandArray );
			if( arguments.quiet ) {
				// A file sink rather than Redirect.DISCARD keeps the pipe from filling
				// while the runner works; the caller owns the file and deletes it.
				processBuilder.redirectErrorStream( true );
				processBuilder.redirectOutput( createObject( "java", "java.io.File" ).init( arguments.discardFile ) );
			} else {
				processBuilder.inheritIO();
			}
			processBuilder.directory( createObject( "java", "java.io.File" ).init( arguments.workingDirectory ) );
			var process = processBuilder.start();
			process.waitFor();
			var exitCode = process.exitValue();
			process.destroy();
			return exitCode;
		} finally {
			if( terminal.paused() ) {
				terminal.resume();
			}
		}
	}

	/**
	 * Reads the JUnit XML the console launcher wrote and tallies it.
	 *
	 * @reportsDirectory The directory the launcher wrote its reports to.
	 * @returns A struct with total, passed, failed, skipped and tests.
	 */
	private struct function readResults( required string reportsDirectory ) {
		var tests = [];

		if( directoryExists( arguments.reportsDirectory ) ) {
			for( var reportFile in directoryList( arguments.reportsDirectory, false, "path", "*.xml" ) ) {
				var doc = xmlParse( fileRead( reportFile ) );
				for( var testCase in xmlSearch( doc, "//testcase" ) ) {
					tests.append( {
						"className" : testCase.xmlAttributes.classname ?: "",
						// The XML carries the display name, which for a method is
						// `methodName()`. Drop the suffix so it matches what a user
						// passes to testClasses=Class#method.
						"name"      : reReplace( testCase.xmlAttributes.name ?: "", "\(\)$", "" ),
						"status"    : testCaseStatus( testCase ),
						"duration"  : round( val( testCase.xmlAttributes.time ?: 0 ) * 1000 ),
						"message"   : testCaseMessage( testCase )
					} );
				}
			}
		}

		var failed = 0;
		var skipped = 0;
		for( var testResult in tests ) {
			if( testResult.status == "FAILED" ) {
				failed++;
			} else if( testResult.status == "SKIPPED" ) {
				skipped++;
			}
		}

		return {
			"total"   : tests.len(),
			"passed"  : tests.len() - failed - skipped,
			"failed"  : failed,
			"skipped" : skipped,
			"tests"   : tests
		};
	}

	/**
	 * Reads the status out of one JUnit XML test case.
	 *
	 * @testCase A parsed testcase node.
	 * @returns PASSED, FAILED or SKIPPED.
	 */
	private string function testCaseStatus( required any testCase ) {
		if( structKeyExists( arguments.testCase, "failure" ) || structKeyExists( arguments.testCase, "error" ) ) {
			return "FAILED";
		}
		if( structKeyExists( arguments.testCase, "skipped" ) ) {
			return "SKIPPED";
		}
		return "PASSED";
	}

	/**
	 * Reads the failure message out of one JUnit XML test case, if it has one.
	 *
	 * @testCase A parsed testcase node.
	 * @returns The message, or an empty string.
	 */
	private string function testCaseMessage( required any testCase ) {
		for( var nodeName in [ "failure", "error", "skipped" ] ) {
			if( structKeyExists( arguments.testCase, nodeName ) ) {
				for( var node in arguments.testCase[ nodeName ] ) {
					if( structKeyExists( node, "xmlAttributes" ) && structKeyExists( node.xmlAttributes, "message" ) ) {
						return node.xmlAttributes.message;
					}
				}
			}
		}
		return "";
	}

	/**
	 * Prints the human-readable test summary.
	 *
	 * @summary The tallied results.
	 * @returns Nothing.
	 */
	private function printTestSummary( required struct summary ) {
		print.line(
			"Tests run: #arguments.summary.total#, Passed: #arguments.summary.passed#, Failed: #arguments.summary.failed#, Skipped: #arguments.summary.skipped#"
		).toConsole();

		if( arguments.summary.total == 0 ) {
			print.yellowLine( "No tests found." ).toConsole();
			return;
		}

		for( var testResult in arguments.summary.tests ) {
			if( ( testResult.status ?: "" ) != "FAILED" ) {
				continue;
			}
			var failedClassName = testResult.className ?: "";
			var failedMethodName = testResult.name ?: "";
			var testLabel = len( failedClassName ) ? failedClassName & chr( 35 ) & failedMethodName : failedMethodName;
			print.redLine( "FAILED #testLabel#" ).toConsole();
			if( len( testResult.message ?: "" ) ) {
				print.line( "  #testResult.message#" ).toConsole();
			}
		}

		if( arguments.summary.failed ) {
			print.redLine( "Tests failed." ).toConsole();
		} else {
			print.greenLine( "All tests passed." ).toConsole();
		}
	}

}

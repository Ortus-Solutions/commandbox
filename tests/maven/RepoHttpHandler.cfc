/**
 * Minimal file-serving HttpHandler used by the Maven endpoint tests to stand up a throw-away
 * Maven repository on 127.0.0.1 with an ephemeral port.
 *
 * Files are served from `scratch/http-repo/` (relative to this CFC) so a test can lay out any
 * repository tree it needs, and every request is appended to `scratch/http-repo-requests.log` so
 * tests can assert *what* was fetched (metadata vs JAR) as well as what was returned.
 *
 * Instantiated in tests via:
 *
 *     createDynamicProxy( "RepoHttpHandler", [ "com.sun.net.httpserver.HttpHandler" ] )
 */
component {

	function handle( required any exchange ) {
		var baseDirectory = getDirectoryFromPath( getCurrentTemplatePath() );
		var repoRoot = baseDirectory & "scratch/http-repo";
		var requestLog = baseDirectory & "scratch/http-repo-requests.log";
		var requestPath = arguments.exchange.getRequestURI().getPath();
		var method = arguments.exchange.getRequestMethod();

		try {
			// Append through java.io.FileWriter - reliable from inside the proxy handler thread, unlike
			// BoxLang's fileWrite() which can silently no-op in this context.
			var writer = createObject( "java", "java.io.FileWriter" ).init( requestLog, true );
			try {
				writer.write( "#method# #requestPath#" & chr( 10 ) );
			} finally {
				writer.close();
			}
		} catch( any e ) {
			// Request logging is best effort - never break a request over it.
		}

		var filePath = repoRoot & replace( requestPath, "/", chr( 92 ), "all" );
		if ( !fileExists( filePath ) ) {
			arguments.exchange.sendResponseHeaders( 404, -1 );
			arguments.exchange.close();
			return;
		}

		var bytes = createObject( "java", "java.nio.file.Files" ).readAllBytes(
			createObject( "java", "java.nio.file.Paths" ).get( filePath )
		);

		arguments.exchange.getResponseHeaders().set( "Content-Type", "application/octet-stream" );

		if( method.lCase() == "head" ) {
			arguments.exchange.sendResponseHeaders( 200, -1 );
		} else {
			arguments.exchange.sendResponseHeaders( 200, bytes.len() );
			arguments.exchange.getResponseBody().write( bytes );
			arguments.exchange.getResponseBody().close();
		}

		arguments.exchange.close();
	}

}

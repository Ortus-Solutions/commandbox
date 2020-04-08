/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* Allows a file to be downloaded progressively with a callback UDF for status
*
*/
component singleton {

	property name='ConfigService' inject='ConfigService';
	property name='shell' inject='shell';

	/**
	* Call me to download a file with a status callback
	* @downloadURL.hint The remote URL to download
	* @destinationFile.hint The local file path to store the downloaded file
	* @statusUDF.hint A closure that will be called once for each full percent of completion. Accepts a struct containing percentage, averageKBPS, totalKB, and downloadedKB
	* @redirectUDF.hint A closure that will be called once for every 30X redirect followed
	*/
	public function download(
		required string downloadURL,
		required string destinationFile,
		any statusUDF,
		any redirectUDF='' ) {

		var data = getByteArray( 1024 );
		var total = 0;
		var currentPercentage = 0;
		var lastPercentage = 0;
		var lastTotalDownloaded = 0;

		// Get connection object, following redirects.
		var info = resolveConnection( arguments.downloadURL, arguments.redirectUDF );
		var connection = info.connection;
		var netURL = info.netURL;
		
		// Initialize status
		var status = {
			percent = 0,
			speedKBps = 0,
			totalSizeKB = -1,
			completeSizeKB = 0
		};

		try {

			var lenghtOfFile = connection.getContentLength();

			var inputStream = createObject( 'java', 'java.io.BufferedInputStream' ).init( connection.getInputStream() );
			var outputStream = createObject( 'java', 'java.io.FileOutputStream' ).init( arguments.destinationFile );

			var currentTickCount = getTickCount();
			var lastTickCount = currentTickCount;
			var kiloBytesPerSecondRunningAverage = [];
			var lastKiloBytesPerSeconde = 0;
			var first = true;

			while ( ( var count = inputStream.read( data ) ) != -1 ) {
				
				// Has the user tried to interrupt this thread?
				shell.checkInterrupted();
				
				total += count;
				// This number will be worthless if content length is -1
				currentPercentage = int( ( total * 100 ) / lenghtOfFile );
				bytesSinceLastUpdate = total - lastTotalDownloaded;
				outputStream.write( data, 0, count );

				// Is there a callback closure
				if( !isNull( arguments.statusUDF ) ) {

					// Have we progressed a full percent?
					// Or if we don't know the total length, have we at least gotten
					if( ( lenghtOfFile == -1 && bytesSinceLastUpdate >= 250000 ) || currentPercentage >= lastPercentage + 1 || first ) {

						currentTickCount = getTickCount();
						milisSinceLastUpdate = currentTickCount - lastTickCount;

						// Make sure time passed since last update in case network got ahead of our loop
						if( milisSinceLastUpdate > 1 ) {
							// Add KBPS to an array so we can get an average
							kiloBytesPerSecondRunningAverage.append( round( ( bytesSinceLastUpdate / 1000 ) * ( 1000 / milisSinceLastUpdate ) ) );
							// Average the last 5 updates
							kiloBytesPerSecond = round( kiloBytesPerSecondRunningAverage.avg() );
							lastKiloBytesPerSeconde = kiloBytesPerSecond;
						// If the last two byte were back-to-back, just reuse the last KBPS number
						} else {
							kiloBytesPerSecond = lastKiloBytesPerSeconde;
						}

						// Build status data to pass to closure
						status = {
							percent = currentPercentage,
							speedKBps = kiloBytesPerSecond,
							totalSizeKB = ( lenghtOfFile == -1 ? -1 : lenghtOfFile/1000 ),
							completeSizeKB = total/1000
						};

						// Call closure
						arguments.statusUDF( status );

						// Prune back array
						if( kiloBytesPerSecondRunningAverage.len() > 4 ) {
							kiloBytesPerSecondRunningAverage.deleteAt( 1 );
						}

						lastTotalDownloaded = total;
						lastPercentage = currentPercentage;
						lastTickCount = currentTickCount;

					} // full percentage check

				} // Closure check
				first = false;
			} // End loop

			outputStream.flush();
			outputStream.close();
			inputStream.close();

			var returnStruct = {
				responseCode = connection.responseCode,
				responseMessage = connection.responseMessage,
				headers = {}
			};
			var headerMapSize = connection.getHeaderFields().size();
			var i = 0; // Skipping the first index on purpose.  It's handled in responseCode and responseMessage
			while( i++<headerMapSize  ) {
				// Ignore empty keys
				if( len( trim( connection.getHeaderFieldKey( i ) ) ) ) {
					// Build up struct of header key/values
					returnStruct.headers[ connection.getHeaderFieldKey( i ) ] =  connection.getHeaderField( i );
				}
			}

			return returnStruct;

		} catch( Any var e ) {
			rethrow;
		} finally {
			if( !isNull( outputStream ) ) {
				outputStream.flush();
				outputStream.close();
			}
			if( !isNull( inputStream ) ) {
				inputStream.close();
			}
		
			if( !isNull( arguments.statusUDF ) ) {
				status.percent = 100;
				arguments.statusUDF( status );
			}
		}

	}

	// Creates a Java byte array of a given size
	private binary function getByteArray( required numeric size ) {
		var emptyByteArray = createObject("java", "java.io.ByteArrayOutputStream").init().toByteArray();
		var byteClass = emptyByteArray.getClass().getComponentType();
		var byteArray = createObject("java","java.lang.reflect.Array").newInstance(byteClass, arguments.size);
		return byteArray;
	}


	// Get connection following redirects
	private function resolveConnection( required string downloadURL, redirectUDF ) {

		var netURL = createObject( 'java', 'java.net.URL' ).init( arguments.downloadURL );

		// Get proxy settings from the config
		var proxyServer=ConfigService.getSetting( 'proxy.server', '' );
		var proxyPort=ConfigService.getSetting( 'proxy.port', 80 );
		var proxyUser=ConfigService.getSetting( 'proxy.user', '' );
		var proxyPassword=ConfigService.getSetting( 'proxy.password', '' );

		// Check if a proxy server is defined
		if( len( proxyServer ) ) {
			var proxyType = createObject( 'java', 'java.net.Proxy$Type' );
			var inetSocketAddress = createObject( 'java', 'java.net.InetSocketAddress' ).init( proxyServer, proxyPort );
			var proxy = createObject( 'java', 'java.net.Proxy' ).init( proxyType.HTTP, inetSocketAddress );

			// If there is a user defined, use our custom proxyAuthenticator
			if( len( proxyUser ) ) {
				var proxyAuthenticator = createObject( 'java', 'com.ortussolutions.commandbox.authentication.ProxyAuthenticator').init( proxyUser, proxyPassword )
				createObject( 'java', 'java.net.Authenticator' ).setDefault( proxyAuthenticator );
			} else {
				createObject( 'java', 'java.net.Authenticator' ).setDefault( JavaCast( 'null', '' ) );
			}

			// Open our connection using the proxy
			var connection = netURL.openConnection( proxy );
		} else {
			// Open a "regular" connection
			var connection = netURL.openConnection();
		}

		// Add user agent so proxies like Cloudflare won't be dumb and block us.
		connection.setRequestProperty( 'User-Agent', 'Mozilla /5.0 (Compatible MSIE 9.0;Windows NT 6.1;WOW64; Trident/5.0)' );

		// Add an Accept header so sources such as gitlab are willing to send files back.
		connection.setRequestProperty( 'Accept', '*/*' );

		// The reason we're following redirects manually, is because the java class
		// won't switch between HTTP and HTTPS without erroring
		connection.setInstanceFollowRedirects( false );

		try {
			connection.connect();
		} catch( Any var e ) {
			throw( message='Connection failure #arguments.downloadURL#', detail=e.message );
		}

		// If we get a redirect, follow it
		if( connection.responseCode >= 300 && connection.responseCode < 400 ) {
			var newURL = connection.getHeaderField( "Location");
			// Deal with relative URLs by creating a new URL using the old one as a base
			// Sometimes the HTTP location header is a relative path.
			var next = createObject( 'java', 'java.net.URL' ).init( netURL, newURL );
          	newURL = next.toExternalForm();

			if( !isSimpleValue( arguments.redirectUDF ) ) {
				arguments.redirectUDF( newURL );
			}

			return resolveConnection( newURL, arguments.redirectUDF );
		}

		// If we didn't get a successful response, bail here
		if( connection.responseCode < 200 || connection.responseCode > 299 ) {
			throw( message='#connection.responseCode# #connection.responseMessage#', detail=arguments.downloadURL );
		}

		return { connection = connection, netURL = netURL };
	}

}

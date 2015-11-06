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
			
		try {
			
			var lenghtOfFile = connection.getContentLength();
		
			var inputStream = createObject( 'java', 'java.io.BufferedInputStream' ).init( netURL.openStream() );
			var outputStream = createObject( 'java', 'java.io.FileOutputStream' ).init( arguments.destinationFile );
				
			var currentTickCount = getTickCount();
			var lastTickCount = currentTickCount;
			var kiloBytesPerSecondRunningAverage = [];
			var lastKiloBytesPerSeconde = 0;
			
			while ( ( var count = inputStream.read( data ) ) != -1 ) {		
				total += count;
				currentPercentage = int( ( total * 100 ) / lenghtOfFile );
				outputStream.write( data, 0, count );
			
				// Is there a callback closure
				if( !isNull( arguments.statusUDF ) ) {
	
					// Have we progressed a full percent?
					if( currentPercentage >= lastPercentage + 1 ) {
						
						currentTickCount = getTickCount();
						bytesSinceLastUpdate = total - lastTotalDownloaded;
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
						var status = {
							percent = currentPercentage,
							speedKBps = kiloBytesPerSecond,
							totalSizeKB = lenghtOfFile/1000,
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
							
			} // End loop
			
			
			outputStream.flush();
			outputStream.close();
			inputStream.close();
		
			return '#connection.responseCode# #connection.responseMessage#';
			
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
		var connection = netURL.openConnection();
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
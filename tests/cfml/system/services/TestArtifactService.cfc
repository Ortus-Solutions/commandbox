component extends="mxunit.framework.TestCase" {

	public void function setUp() {
		artifactsRoot = getTempDirectory() & "commandbox-artifact-tests-" & createUUID() & "/";
		directoryCreate( artifactsRoot );

		service = new commandbox.system.services.ArtifactService();
		service.setArtifactDir( artifactsRoot );
		service.setConfigService( {
			getSetting = function( required string name, defaultValue ) {
				return arguments.defaultValue ?: "";
			}
		} );
	}

	public void function tearDown() {
		if ( directoryExists( artifactsRoot ) ) {
			directoryDelete( artifactsRoot, true );
		}
	}

	public void function testCreateArtifactPublishesACompleteZipAndLeavesNoStagingFile() {
		var sourceZip = artifactsRoot & "source.zip";
		zipFolder( writePackageFolder( "from-zip", "from zip" ), sourceZip );

		service.createArtifact( "mypackage", "1.2.3", sourceZip );

		var artifactPath = service.getArtifactPath( "mypackage", "1.2.3", false );
		assertTrue( service.artifactExists( "mypackage", "1.2.3" ) );
		assertEquals( "from zip", readHello( artifactPath ) );
		assertEquals( "mypackage.zip", arrayToList( directoryList( getDirectoryFromPath( artifactPath ), false, "name" ) ) );
		assertEquals( [ "1.2.3" ], service.listArtifacts( "mypackage" ).mypackage );
	}

	public void function testCreateArtifactFromFolderPublishesACompleteZip() {
		var packageFolder = writePackageFolder( "from-folder", "from folder" );

		service.createArtifactFromFolder( "mypackage", "3.4.5", packageFolder );

		assertEquals( "from folder", readHello( service.getArtifactPath( "mypackage", "3.4.5", false ) ) );
		assertEquals( 0, countPartialFiles( artifactsRoot ) );
	}

	public void function testReplacingAnArtifactPublishesTheNewZipWhole() {
		var packageFolder = writePackageFolder( "replace-me", "first" );
		service.createArtifactFromFolder( "mypackage", "1.0.0", packageFolder );

		fileWrite( packageFolder & "/hello.txt", "second" );
		service.createArtifactFromFolder( "mypackage", "1.0.0", packageFolder );

		var artifactPath = service.getArtifactPath( "mypackage", "1.0.0", false );
		assertEquals( "second", readHello( artifactPath ) );
		assertEquals( "mypackage.zip", arrayToList( directoryList( getDirectoryFromPath( artifactPath ), false, "name" ) ) );
	}

	public void function testInProgressVersionIsNotListedUntilTheZipIsPublished() {
		directoryCreate( artifactsRoot & "mypackage/9.9.9", true );
		fileWrite( artifactsRoot & "mypackage/9.9.9/.orphan.partial", "incomplete" );

		assertFalse( service.artifactExists( "mypackage", "9.9.9" ) );
		assertFalse( structKeyExists( service.listArtifacts( "mypackage" ), "mypackage" ) );
		assertEquals( "", service.findSatisfyingVersion( "mypackage", "9.9.9" ) );
	}

	public void function testRejectedMoveLeavesThePreviousArtifactAndRemovesTheStagingFile() {
		var sourceZip = artifactsRoot & "source.zip";
		zipFolder( writePackageFolder( "seed", "first" ), sourceZip );
		service.createArtifact( "mypackage", "1.0.0", sourceZip );

		fileWrite( artifactsRoot & "seed/hello.txt", "second" );
		zipFolder( artifactsRoot & "seed", sourceZip );

		injectMethod(
			receiver = service,
			giver = this,
			functionName = "rejectAtomicMove",
			functionNameInReceiver = "moveArtifactAtomically"
		);

		try {
			service.createArtifact( "mypackage", "1.0.0", sourceZip );
			fail( "createArtifact should have aborted when the atomic move was rejected" );
		} catch ( TestAtomicMoveFailure var ignored ) {
		}

		assertTrue( request.observedMove.sourceExists );
		assertTrue( request.observedMove.sourceSize > 0 );
		assertEquals( request.observedMove.sourceDirectory, request.observedMove.targetDirectory );
		assertTrue( request.observedMove.sourceName != request.observedMove.targetName );
		assertEquals( "first", readHello( service.getArtifactPath( "mypackage", "1.0.0", false ) ) );
		assertEquals( 0, countPartialFiles( artifactsRoot ) );
	}

	/**
	* Stand-in for a filesystem that refuses the publish step. This runs on the service,
	* so it records what it saw and lets the test method assert it.
	*/
	public void function rejectAtomicMove( required string sourcePath, required string targetPath ) {
		request.observedMove = {
			sourceExists : fileExists( arguments.sourcePath ),
			sourceSize : getFileInfo( arguments.sourcePath ).size,
			sourceDirectory : getDirectoryFromPath( arguments.sourcePath ),
			targetDirectory : getDirectoryFromPath( arguments.targetPath ),
			sourceName : getFileFromPath( arguments.sourcePath ),
			targetName : getFileFromPath( arguments.targetPath )
		};
		throw( type = "TestAtomicMoveFailure", message = "rejected atomic move" );
	}

	private string function writePackageFolder( required string name, required string contents ) {
		var packageFolder = artifactsRoot & arguments.name & "/";
		directoryCreate( packageFolder, true );
		fileWrite( packageFolder & "hello.txt", arguments.contents );
		return packageFolder;
	}

	private string function zipFolder( required string packageFolder, required string zipPath ) {
		zip action="zip" source=arguments.packageFolder file=arguments.zipPath overwrite=true;
		return arguments.zipPath;
	}

	private string function readHello( required string zipPath ) {
		var destination = artifactsRoot & "unzipped-" & createUUID() & "/";
		directoryCreate( destination );
		zip action="unzip" file=arguments.zipPath destination=destination overwrite=true;
		return fileRead( destination & "hello.txt" );
	}

	private numeric function countPartialFiles( required string directory ) {
		var partials = directoryList(
			path = arguments.directory,
			recurse = true,
			listInfo = "path",
			filter = "*.partial"
		);
		return arrayLen( partials );
	}

}

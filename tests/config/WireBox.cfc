component extends="commandbox.system.config.WireBox"{

	function configure(){
		super.configure();

		var testString = "";
		var bain = createObject( "java", "java.io.ByteArrayInputStream" ).init( testString.getBytes() );
		var baos = createObject( "java", "java.io.ByteArrayOutputStream" ).init();


		// map Shell
		unmap( "Shell" );
		map( "Shell" )
			.to( "commandbox.system.Shell" )
			.initArg( name="inStream", value=bain )
			.initArg( name="outputStream", value=baos )
			//.initArg( name="userDir", value=expandPath( "/tests/temp" ) )
			.initArg( name="tempDir", value=expandPath( "/tests/temp" ) )
			.initArg( name="asyncLoad", value=false )


	}

}
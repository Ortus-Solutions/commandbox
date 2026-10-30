/**
 * Writes editor metadata for the Java project so editors resolve the sources and
 * dependencies declared in the box.json java block.
 *
 * {code:bash}
 * java ide-init
 * {code}
 *
 * Editors in use are detected from the project, and each one gets its metadata
 * generated. Existing files are merged, so settings that are not ours are kept.
 * Eclipse and IntelliJ list the dependency JARs as they are at generation time,
 * so re-run this after installing dependencies.
 **/
component extends="commandbox.system.BaseCommand" {

	property name="javaIDEModel"   inject="JavaIDEModel";
	property name="javaIDEService" inject="JavaIDEService";

	function run() {
		var results = javaIDEService.write( javaIDEModel.build( getCWD() ) );
		for( var result in results ) {
			variables.print.line( "Detected #result.ide#. Wrote:" );
			for( var file in result.files ) {
				variables.print.line( "    #file#" );
			}
		}
	}
}

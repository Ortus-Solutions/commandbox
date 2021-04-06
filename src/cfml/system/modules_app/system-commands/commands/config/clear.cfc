/**
 * Remove a setting out of the commandbox.json.
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * .
 * {code:bash}
 * config clear description
 * {code}
 *
 **/
component {

	property name="ConfigService" inject="ConfigService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint Name of the property to clear
	 * @property.optionsUDF completeProperty
	 **/
	function run( required string property ) {

		var configSettings = ConfigService.getconfigSettings( noOverrides=true );

		try {
			JSONService.clear( configSettings, arguments.property );
		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

		print.greenLine( 'Removed #arguments.property#' );

		// Write the file back out.
		ConfigService.setConfigSettings( configSettings );

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		return ConfigService.completeProperty();
	}

}

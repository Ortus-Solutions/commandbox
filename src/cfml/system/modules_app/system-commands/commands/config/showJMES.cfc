/**
 * View configuration properties in CommandBox. Call with no parameters to view all config properties.
 * .
 * JMESPath is a query language built specifically for interacting with JSON type data. More information
 * can be found at https://jmespath.org/ as well as an online version to test your query
 * Pass or pipe the text to process or a filename
 *
 * Output setting
 * {code:bash}
 * config show settingName
 * {code}
 * .
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * {code:bash}
 * config show modules.myModule.settingName
 * {code}
 * .
 * {code:bash}
 * config show mySettingArray[1]
 * {code}
 * .
 **/
component {

	property name="ConfigService" inject="ConfigService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 **/
	function run( string property='' ) {

		var configSettings = ConfigService.getconfigSettings();

		try {

			var propertyValue = JSONService.showJMES( configSettings, arguments.property );

			if( isSimpleValue( propertyValue ) ) {
				print.line( propertyValue );
			} else {
				print.line( propertyValue );
			}

		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

	}

	// Dynamic completion for property name based on contents of commandbox.json
	function completeProperty() {
		return ConfigService.completeProperty();
	}
}

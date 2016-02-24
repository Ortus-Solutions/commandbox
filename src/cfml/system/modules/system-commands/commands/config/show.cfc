/**
 * View configuration proprties in CommandBox. Call with no parameters to view all config properties.
 * .
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
			
			var propertyValue = JSONService.show( configSettings, arguments.property );
			
			if( isSimpleValue( propertyValue ) ) {
				print.line( propertyValue );
			} else {
				print.line( formatterUtil.formatJson( propertyValue ) );			
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
/**
 * Set config settings in commandbox.json.
 * .
 * {code:bash}
 * config set name=mySetting
 * {code}
 * .
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * If the set value is JSON, it will be stored as a complex value in the commandbox.json.
 * .
 * Set module setting
 * {code:bash}
 * config set modules.myModule.mySetting=foo
 * {code}
 * .
 * Set item in an array
 * {code:bash}
 * config set myArraySetting[1]="value"
 * {code}
 * .
 * Set multiple params at once
 * {code:bash}
 * config set setting1=value1 setting2=value2 setting3=value3
 * {code}
 * .
 * Override a complex value as JSON
 * {code:bash}
 * config set myArraySeting="[ 'test@test.com', 'me@example.com' ]"
 * {code}
 * .
 * Structs and arrays can be appended to using the "append" parameter.
 * .
 * Add an additional settings to the existing list
 * This only works if the property and incoming value are both of the same complex type.
 * {code:bash}
 * config set myArraySetting="[ 'another value' ]" --append
 * {code}
 *
 **/
component {

	property name="ConfigService" inject="ConfigService";
	property name="JSONService" inject="JSONService";

	/**
	 * This param is a dummy param just to get the custom completor to work.
	 * The actual parameter names will be whatever property name the user wants to set
	 * @_.hint Pass any number of property names in followed by the value to set
	 * @_.optionsUDF completeProperty
	 * @append.hint If setting an array or struct, set to true to append instead of overwriting.
	 **/
	function run( _, boolean append=false ) {
		var thisAppend = arguments.append;

		// Remove dummy args
		structDelete( arguments, '_' );
		structDelete( arguments, 'append' );

		var configSettings = ConfigService.getconfigSettings();

		var results = JSONService.set( configSettings, arguments, thisAppend );

		// Write the file back out.
		ConfigService.setConfigSettings( configSettings );

		for( var message in results ) {
			print.greeLine( message );
		}

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		// all=true will cause "config set" to prompt all possible commandbox.json settings
		return ConfigService.completeProperty( true, true );
	}
}
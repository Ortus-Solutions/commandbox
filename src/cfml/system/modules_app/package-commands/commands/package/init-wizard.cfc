/**
 * Initialize a package in the current directory by creating a default box.json file using our lovely wizard
 **/
component extends="init" aliases="" {

	/**
	 * @name The human-readable name for this package
	 * @slug The ForgeBox or unique slug for this package (no spaces or special chars)
	 * @version The version for this package, please use semantic versioning - 0.0.0
	 * @private Mark your package as private, so that if it is published to ForgeBox, only you can see it.
	 * @shortDescription A short description for the package
	 * @author The author of the package, you!
	 * @keywords A nice list of keywords that describe your package
	 * @homepage Your package's homepage URL
	 * @ignoreList Add commonly ignored files to the package's ignore list
	 **/
	function run(
		required name,
		required slug,
		required version,
		required boolean private,
		required shortDescription,
		required author,
		required keywords,
		required homepage,
		required boolean ignoreList
	){
		// turn off wizard
		arguments.wizard = false;
		super.run( argumentCollection=arguments );
	}
}

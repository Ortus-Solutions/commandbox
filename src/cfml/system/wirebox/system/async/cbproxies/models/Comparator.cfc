/**
 * Functional interface that maps to java.util.Comparator
 * See https://docs.oracle.com/javase/8/docs/api/java/util/Comparator.html
 */
component extends="BaseProxy" {

	/**
	 * Constructor
	 *
	 * @f Target lambda or closure
	 */
	function init( required f ){
		super.init( arguments.f );
		return this;
	}

	/**
	 * Compares its two arguments for order.
	 */
	function compare( o1, o2 ){
		return execute(
			( struct args ) => {
				return variables.target( args.o1, args.o2 );
			},
			"Comparator",
			arguments
		);
	}

}

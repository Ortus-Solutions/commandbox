/**
 * Functional interface that maps to java.util.function.BinaryOperator
 * See https://docs.oracle.com/javase/8/docs/api/java/util/function/BinaryOperator.html
 */
component extends="BiFunction" {

	/**
	 * Functional interface for the apply functional interface
	 * See https://docs.oracle.com/javase/8/docs/api/java/util/function/BiFunction.html#apply-T-U-
	 */
	function apply( t, u ){
		return execute(
			( struct args ) => {
				return variables.target(
					isNull( args.t ) ? javacast( "null", "" ) : args.t,
					isNull( args.u ) ? javacast( "null", "" ) : args.u
				);
			},
			"BinaryOperator",
			arguments
		);
	}

}

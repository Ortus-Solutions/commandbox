package example;

public class Example {
	public static void main( String[] args ) {
		System.out.println( "Hello, World!" );
		System.out.println( "PROP: " + System.getProperty( "test.prop", "unset" ) );
		for( var arg : args ) {
			System.out.println( "ARG: " + arg );
		}
	}
}

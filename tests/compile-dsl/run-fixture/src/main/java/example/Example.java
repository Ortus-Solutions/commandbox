package example;

public class Example {
	public static void main( String[] args ) {
		System.out.println( "Hello, World!" );
		for( var arg : args ) {
			System.out.println( "ARG: " + arg );
		}
	}
}

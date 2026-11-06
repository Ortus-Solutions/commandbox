package example;

/**
 * A compiled test class that no runner on the classpath can execute. The fixture
 * has an empty devDependencies block on purpose.
 */
public class PlainTest {

	public void twice() {
		new Plain().twice( 2 );
	}

}
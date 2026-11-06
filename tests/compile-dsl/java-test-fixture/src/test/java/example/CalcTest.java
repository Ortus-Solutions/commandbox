package example;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

/**
 * Passing tests used by the java test fixture.
 */
public class CalcTest {

	@Test
	public void addsTwoNumbers() {
		assertEquals( 3, new Calc().add( 1, 2 ) );
	}

	@Test
	public void addsNegativeNumbers() {
		assertEquals( -1, new Calc().add( 1, -2 ) );
	}

}

/**
*
*	StringSimilarity
*	Brad Wood
*	brad@bradwood.com
*	May 2007
*	Code adopted from Siderite Zackwehdex's Blog
*		http://siderite.blogspot.com/2007/04/super-fast-and-accurate-string-distance.html
*/
component singleton {

	/**
	* @s1 First string to be compared
	* @s2 Second string to be compared
	* @maxOffset Average number of characters that s1 will deviate from s2 at any given point.
	*					This is used to control how far ahead the function looks to try and find the 
	*					end of a peice of inserted text.  Play with it to suit.
	*/

    function stringSimilarity( s1, s2, maxOffset)
        {
            var c = 0;
            var offset1 = 0;
            var offset2 = 0;
            var lcs = 0;
			// These two strings will contain the "highlighted" version
			var _s1 = createObject("java","java.lang.StringBuffer").init(javacast("int",len(s1)*3));
			var _s2 = createObject("java","java.lang.StringBuffer").init(javacast("int",len(s2)*3));
			// These charactes will surround differences in the strings 
			// (Inserted into _s1 and _s2)
			var h1 = chr( 27 ) & "[1m";
			var h2 = chr( 27 ) & "[0m";
			var return_struct = structNew();
			// If both strings are empty 
            if (not len(trim(s1)) and not len(trim(s2)))
				{	
					return_struct.lcs = 0;
					return_struct.similarity = 1;
					return_struct.distance = 0;
					return_struct.s1 = "";
					return_struct.s2 = "";
		            return return_struct;
				}
			// If s2 is empty, but s1 isn't
            if (len(trim(s1)) and not len(trim(s2)))
				{
					return_struct.lcs = 0;
					return_struct.similarity = 0;
					return_struct.distance = len(s1);
					return_struct.s1 = h1 & s1 & h2;
					return_struct.s2 = "";
		            return return_struct;
				}
			// If s1 is empty, but s2 isn't
			else if (len(trim(s2)) and not len(trim(s1)))
				{
					return_struct.lcs = 0;
					return_struct.similarity = 0;
					return_struct.distance = len(s2);
					return_struct.s1 = "";
					return_struct.s2 = h1 & s2 & h2;
		            return return_struct;
				}
				
			// Examine the strings, one character at a time, anding at the shortest string
			// The offset adjusts for extra characters in either string.
            while ((c + offset1 lt len(s1))
                   and (c + offset2 lt len(s2)))
            {
				// Pull the next charactes out of s1 anbd s2
				next_s1 = mid(s1,c + offset1+1,iif(not c,3,1)); // First time through check the first three
				next_s2 = mid(s2,c + offset2+1,iif(not c,3,1)); // First time through check the first three
				// If they are equal
                if (compare(next_s1,next_s2) eq 0)
					{
						// Our longeset Common String just got one bigger
						lcs = lcs + 1;
						// Append the characters onto the "highlighted" version
						_s1.append(left(next_s1,1));
						_s2.append(left(next_s2,1));
					}
				// The next two charactes did not match
				// Now we will go into a sub-loop while we attempt to 
				// find our place again.  We will only search as long as
				// our maxOffset allows us to.
                else
	                {
						// Don't reset the offsets, just back them up so you 
						// have a point of reference
	                    old_offset1 = offset1;
	                    old_offset2 = offset2;
						_s1_deviation = "";
						_s2_deviation = "";
						// Loop for as long as allowed by our offset 
						// to see if we can match up again
	                    for (i = 0; i lt maxOffset; i=i+1)
	                    {
							next_s1 = mid(s1,c + offset1 + i+1,3); // Increments each time through.
							len_next_s1 = len(next_s1);
							bookmarked_s1 = mid(s1,c + offset1+1,3); // stays the same
							next_s2 = mid(s2,c + offset2 + i+1,3); // Increments each time through.
							len_next_s2 = len(next_s2);
							bookmarked_s2 = mid(s2,c + offset2+1,3); // stays the same
							
							// If we reached the end of both of the strings
							if(not len_next_s1 and not len_next_s2)
								{
									// Quit
									break;
								}
							// These variables keep track of how far we have deviated in the
							// string while trying to find our match again.
							_s1_deviation = _s1_deviation & left(next_s1,1);
							_s2_deviation = _s2_deviation & left(next_s2,1);
							// It looks like s1 has a match down the line which fits
							// where we left off in s2
	                        if (compare(next_s1,bookmarked_s2) eq 0)
		                        {
									// s1 is now offset THIS far from s2
		                            offset1 =  offset1+i;
									// Our longeset Common String just got bigger
									lcs = lcs + 1;
									// Now that we match again, break to the main loop
		                            break;
		                        }
								
							// It looks like s2 has a match down the line which fits
							// where we left off in s1
	                        if (compare(next_s2,bookmarked_s1) eq 0)
		                        {
									// s2 is now offset THIS far from s1
		                            offset2 = offset2+i;
									// Our longeset Common String just got bigger
									lcs = lcs + 1;
									// Now that we match again, break to the main loop
		                            break;
		                        }
	                    }
						//This is the number of inserted characters were found
						added_offset1 = offset1 - old_offset1;
						added_offset2 = offset2 - old_offset2;
						
						// We reached our maxoffset and couldn't match up the strings
						if(added_offset1 eq 0 and added_offset2 eq 0)
							{
								_s1.append(h1 & left(_s1_deviation,added_offset1+1) & h2);
								_s2.append(h1 & left(_s2_deviation,added_offset2+1) & h2);
							}
						// s2 had extra characters
						else if(added_offset1 eq 0 and added_offset2 gt 0)
							{
								_s1.append(left(_s1_deviation,1));
								_s2.append(h1 & left(_s2_deviation,added_offset2) & h2 & right(_s2_deviation,1));
							}
						// s1 had extra characters
						else if(added_offset1 gt 0 and added_offset2 eq 0)
							{
								_s1.append(h1 & left(_s1_deviation,added_offset1) & h2 & right(_s1_deviation,1));
								_s2.append(left(_s2_deviation,1));
							}
	                }
                c=c+1;	
            }
			// Anything left at the end of s1 is extra
			if(c + offset1 lt len(s1))
				{
					_s1.append(h1 & right(s1,len(s1)-(c + offset1)) & h2);
				}
			// Anything left at the end of s2 is extra
			if(c + offset2 lt len(s2))
				{
					_s2.append(h1 & right(s2,len(s2)-(c + offset2)) & h2);
				}
				
			// Distance is the average string length minus the longest common string
			distance = (len(s1) + len(s2))/2 - lcs;
			// Whcih string was longest?
			maxLen = iif(len(s1) gt len(s2),de(len(s1)),de(len(s2)));
			// Similarity is the distance divided by the max length
			similarity = iif(maxLen eq 0,1,1-(distance/maxLen));
			// Return what we found.
			return_struct.lcs = lcs;
			return_struct.similarity = similarity;
			return_struct.distance = distance;
			return_struct.s1 = _s1.toString(); // "highlighted" version
			return_struct.s2 = _s2.toString(); // "highlighted" version
            return return_struct;
        }



}
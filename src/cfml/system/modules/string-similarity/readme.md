# String Similarity

 This is a small library based on the Levenshtein Distance Algorithm tha compares small strings to look for the number of characters that's different between them.  It returns the longest common string (LCS), a percentage of similarity, and can also wrap the differences in HTML tags of your choice to highlight the differences.

Read more about how it works here:

http://www.codersrevolution.com/blog/ColdFusion-Levenshtein-Distance-String-comparison-and-highlighting

```html
<cfset string1 = "The rain in Spain stays mainly on the plains
				The rain in Spain stays mainly on the plains
				The rain in Spain stays mainly on the plains
				Lorum Ipsum, yadda yadda.
				Lorum Ipsum, yadda yadda.
				La La La La Luke, I am your father.">

<cfset string2 = "The rain in Madrid stays totally on the plains
				The rain in Spain stays mainly on the plains
				The rain in Barcelona stays entirely in the air
				Lorum Ipsum, Yabba dabba doo.
				Whatcha eatin?  Nutin' Honey.
				Da Da Da Duke, I am your father.">

<cfset comparison_result = stringSimilarity(string1,string2,10)>

<cfoutput>
Roughly #comparison_result.distance# characters are different between the two strings.<br>
The strings are a #numberformat(comparison_result.similarity*100)#% match.<br>
The Longest Common String is #comparison_result.lcs#.<br>
<br>
<table border="1" cellpadding="10" cellspacing="0">
	<tr>
		<td>
			#replacenocase(comparison_result.s1,chr(10),"<br>","all")#
		</td>
		<td>
			#replacenocase(comparison_result.s2,chr(10),"<br>","all")#
		</td>
	<tr>
</table>
</cfoutput>
```

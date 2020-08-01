/**
 * Display basic information about the shell and some cool ASCII art.
 * .
 * {code:bash}
 * info
 * {code}
 *
 **/
component aliases="about" {

	function run() {

		var width = 100;

		var shellVersion = shell.getVersion();
		var CFMLEngine = server.coldfusion.productName;
		if( structKeyExists( server, CFMLEngine ) ) {
			var CFMLVersion = '#server[ CFMLEngine ].version# #server[ CFMLEngine ].state# (#server[ CFMLEngine ].versionName#)';
		} else {
			var CFMLVersion = server.coldfusion.productVersion;
		}
		var javaVersion = '#server.java.version# (#server.java.vendor#)';
		var commandboxHome = expandpath( '/commandbox-home' );
		var binaryPath = getSystemSetting( 'java.class.path', 'Unknown' );
		var userName = getSystemSetting( 'user.name', 'Unknown' );
		var javaBinary = fileSystemUtil.getJREExecutable();
		var JLineTerminal = shell.getReader().getTerminal().getClass().getName();
		var runwarVersion = 'Unknown';
		try {
			var runwarClass = createObjecT( 'java', 'runwar.Server' );
			runwarVersion = runwarClass.getVersion();
			
			var runwarJarPath = createObject( "java", "java.io.File" )
				.init( runwarClass.getClass().getProtectionDomain().getCodeSource().getLocation().toURI().getSchemeSpecificPart() ).getAbsolutePath();
				
			runwarVersion &= ' (#runwarJarPath#)'
		}catch( any e ) {}

		print.line();
		print.greenLine( '****************************************************************************************************' );
		print.greenText( '*                                         ' );
		print.redBoldText( 'About CommandBox' );
		print.greenLine( '                                         *' );
		print.greenLine( '****************************************************************************************************' );
		print.greenLine( '*                                                                                                  *' );
		print.greenLine( '*                                                                                                  *' );
		print.green( '*' ); print.cyan( '  CommandBox Version: ' ); print.text( '#shellVersion##repeatString( ' ', max( 0, width - 24 - len( shellVersion ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  CommandBox Authors: ' ); print.text( 'Brad Wood, Luis Majano, Denny Valiant                                       ' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  CommandBox Binary   ' ); print.text( '#binaryPath##repeatString( ' ', max( 0, width - 24 - len( binaryPath ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  CommandBox Home     ' ); print.text( '#commandboxHome##repeatString( ' ', max( 0, width - 24 - len( commandboxHome ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  CFML Engine:        ' ); print.text( '#CFMLEngine##repeatString( ' ', max( 0, width - 24 - len( CFMLEngine ) ) )#' );		print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  CFML Version:       ' ); print.text( '#CFMLVersion##repeatString( ' ', max( 0, width - 24 - len( CFMLVersion ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  Java Version:       ' ); print.text( '#javaVersion##repeatString( ' ', max( 0, width - 24 - len( javaVersion ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  Java Path:          ' ); print.text( '#javaBinary##repeatString( ' ', max( 0, width - 24 - len( javaBinary ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  OS Username         ' ); print.text( '#userName##repeatString( ' ', max( 0, width - 24 - len( userName ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  JLine Terminal      ' ); print.text( '#JLineTerminal##repeatString( ' ', max( 0, width - 24 - len( JLineTerminal ) ) )#' );	print.greenLine( '*' );
		print.green( '*' ); print.cyan( '  Runwar Version      ' ); print.text( '#runwarVersion##repeatString( ' ', max( 0, width - 24 - len( runwarVersion ) ) )#' );	print.greenLine( '*' );
		print.greenLine( '*                                                                                                  *' );
		print.greenLine( '*                                                                                                  *' );
		print.greenLine( '****************************************************************************************************' );
		print
			.line()
			.line()
			.line( '                                  Here is an ASCII art stereogram.' )
			.line( '                   Stare at it and diverge your eyes (the opposite of crossing them)' )
			.line( '                             If you can''t see it, you can come back later.' )
			.line( '                This image will be here all day.  Tomorrow holds a new day and a new image.' )
			.line()
			.line()
			.line()
			.line()
			.line();

		var art = getArt()
			.listToArray( chr( 10 ) );
		var longestLine = art.reduce(
			function( prev, line ) {
				return max( prev, line.len() );
			},
			0
		);
		var padding = int( ( 100 - longestLine ) / 2 );
		
		print.line(
			art.map( function( line ) {
				return repeatString( ' ', padding ) & line;
			} )
			.toList( chr( 10 ) ),
			'color#getColor()#'
		)
		.line()
		.line();

	}

	private function getColor() {
		var colors = [1,2,3,6,7,9,10,11,12,13,14,15,1,2,3,6,7,9,10,11,12,13,14,15,1,2,3,6,7,9];
		return colors[ min( day( now() ), 30 ) ];
	}

	private function getArt() {
		
var images = ['

                            O         O
.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .
 .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
   .    .    .    .    .    .    .    .    .    .    .    .    .
   .     .     .     .     .     .     .     .     .     .     .
     .      .      .      .      .      .      .      .      .
 .       .       .       .       .       .       .       .       .
      .        .        .        .        .        .        .
   .         .         .         .         .         .         .
.          .          .          .          .          .          .
|          |          |          |          |          |          |
|          |          |          |          |          |          |
|          |          |          |          |          |          |
|          |          |          |          |          |          |
|          |          |          |          |          |          |
|          |          |          |          |          |          |
   .         .         .         .         .         .         .
      .        .        .        .        .        .        .
 .       .       .       .       .       .       .       .       .
     .      .      .      .      .      .      .      .      .
   .     .     .     .     .     .     .     .     .     .     .
   .    .    .    .    .    .    .    .    .    .    .    .    .
 .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .   .
.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .

','


V              V              V              V              V
OIWEQPOISDFBKJFOIWEQPOISDFBKJFOIWEQPOISDFBKJFOIWEQPOISDFBKJF
EDGHOUIEROUIYWEVDGHOXUIEROIYWEVDGHEOXUIEOIYWEVDGHEOXUIEOIYWE
KJBSVDBOIWERTBAKJBSVEDBOIWRTBAKJBSOVEDBOWRTBAKJBSOVEDBOWRTBA
SFDHNWECTBYUVRGSFDHNYWECTBUVRGSFDHCNYWECBUVRGSFDHCNYWECBUVRG
HNOWFHLSFDGWVRGHNOWFGHLSFDWVRGHNOWSFGHLSDWVRGHNLOWSFGLSDWVRG
YPOWVXTNWFECHRGYPOWVEXTNWFCHRGYPOWNVEXTNFCHRGYPWOWNVETNFCHRG
SVYUWXRGTWVETUISVYUWVXRGTWVETUISVYUWVXRGWVETUISVYUWVXRGWVETU
WVERBYOIAWEYUIVWVERBEYOIAWEYUIVWVERBEYOIWEYUIVWLVERBEOIWEYUI
EUIOETOUINWEBYOEUIOEWTOUINWEBYOEUIOEWTOUNWEBYOETUIOEWOUNWEBY
WFVEWVETN9PUW4TWFVEWPVETN9UW4TWFVETWPVET9UW4TWFBVETWPET9UW4T
NOUWQERFECHIBYWNOUWQXERFECIBYWNOUWFQXERFCIBYWNOFUWFQXRFCIBYW
VEHWETUQECRFVE[VEHWERTUQECFVE[VEHWQERTUQCFVE[VEOHWQERUQCFVE[
UIWTUIRTWUYWQCRUIWTUYIRTWUWQCRUIWTXUYIRTUWQCRUIBWTXUYRTUWQCR
IYPOWOXNPWTHIECIYPOWTOXNPWHIECIYPONWTOXNWHIECIYLPONWTXNWHIEC
R9UHWVETPUNRQYBR9UHWVETPUNRQYBR9UHWVETPUNRQYBR9UHWVETPUNRQYB
X              X              X              X              X

','

   g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g  g
   r   r   r   r   r   r   r   r   r   r   r   r   r   r   r   r   r   r   r
    e    e    e    e    e    e    e    e    e    e    e    e    e    e    e
   a     a     a     a     a     a     a     a     a     a     a     a     a
    t      t      t      t      t      t      t      t      t      t      t
   <<<<>>>><<<<>>>><<<<>>>><<<<>>>><<<<>>>><<<<>>>><<<<>>>><<<<>>>><<<<>>>>
    d      d      d      d      d      d      d      d      d      d      d
   e     e     e     e     e     e     e     e     e     e     e     e     e
    p    p    p    p    p    p    p    p    p    p    p    p    p    p    p
   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t   t
   h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h  h

','   
   
   X               X               X               X               X               
NCHgXng4<##\xfy@DNCHgXng4<##\xfy@DNCHgXng4<##\xfy@DNCHgXng4<##\xfy@DNCHgXng4<##\xfy@
@cQguJ/-@"",{0%t@cQguJ/-@"",{0%t@cQguJ/-@"",{0%t@cQguJ/-@"",{0%t@cQguJ/-@"",{0%
RM_.fqAMsHH(lgLXRM_.fqAMsHH(lgLXRM_.fqAMsHH(lgLXRM_.fqAMsHH(lgLXRM_.fqAMsHH(lgL
MHBm=yE\zG4x"8pTMHB=yE\zG4x"8pT0MHB=yE\zG4"8pT0zMHB=yE\z4"8p-T0zMHB=yE\4"8pu-T0
:uFYi9`$$/[x"!5?:uFi9`$$/[x"!5?E:uFi9`$/[x"!5?E:uFYi9`$/x"!5z?E:uFYi9`$x"!5Bz?E
K1fMq%$$JXycxjgdK1fq%$$JXycxjgd&K1fq%$JXycxjgd&K1fq%K$JXcxjghd&K1fq%K$JcxjgQhd&
%Fu''n-E6ej$4{5,o%Fun-E69ej$4{5,o%FunE69ejW$4{5,o%unE6>9ej$4{5.,o%unE6>ej$42{5.,
b<-O''=!Q(y!uq''3!b<-''=!QK(y!uq''3!b<-''!QK(Hy!uq''3!b-''!Q2K(H!uq''93!b-''!Q2(H!usq''93
m_+Dykz:D/|`cvf##m_+ykz:BD/|`cvf##m_+kz:BbD/|`cvf##m_+kz:BbD|`cvRf##m_+kz:bD|`?cvRf
bK[i]\_P9CoQMEtqbK[]\_P49CoQMEtqbK[\_P4q9CoQMEtqbK[\_P4q9CQMEt/qbK[\_4q9C##QMEt/
KVbYws\=XY''fOazWKVbws\=hXY''fOazWKVbs\=h\XY''fOazWKVbs\=h\XYfOaz+WKVbs\h\XY$fOaz+
KE|wi?8H[nK)G0biKE|i?8HO[nK)G0biKE|i8HO[niK)G0biKE|i8HO[ni)G0bQiKE|i8O[niR)G0bQ
EW;@<8v''@LSjpR0]EW;<8v''q@LSjpR0]EW;<8''q@LSjpRG0]EW;<8''q@LSjRG0](EW;<''q@LwSjRG0]
`R$R.1?(EoY5JtTe`R$.1?(EoY5Jt/Te`R$.1?(oY5Jt/Te`NR$.1?(oY5J/Te`kNR$.?(oYN5J/Te`
yicm??M[1|Uqz$FSyic??M[1|Uqz$\FSyic??M[1|Uz$\FSyicd??M[1|Uz\FSyZicd?M[1|$Uz\FSy
##6aL-8\der]._DzI##6a-8\der]._D.zI##6a-8\der]._D.I##6a-r8\der]._.I##6Oa-8\de>r]._.I##
=OZ:{$lZ3I*]+jT7=OZ{$lZM3I*]+jT7=OZ{$lZM3I*]+jT7OZ{$3lZM3I*]jT7OFZ{3lZM^3I*]jT7
Q''k[r4''##Q!h9OFSMQ''kr4''##qQ!h9OFSMQ''kr4''##qQ!h9OFSMQkr4''j##qQ!h9FSMQSkr''j##qOQ!h9FSM
_(0i=cKiBqrrw,xl_(0=cKigBqrrw,xl_(0=cKigBqrrw,xl_0=cKJigBqrrwxl_0:cKJi;gBqrrwxl
J%TxrRqfgo9Ivp]6J%TrRqfVgo9Ivp]6J%TrRqfVgo9Ivp]6JTrRq,fVgo9Iv]6JTJRq,fCVgo9Iv]6
Hh`Bs[Y^(rDQvCulHh`s[Y^@(rDQvCulHh`s[Y^@(rDQvCulH`s[Y5^@(rDQvulH`![Y5^+@(rDQvul
''9SHT4).gzx2e\{(''9ST4).:gzx2e\{(''9T4).W:gzx2e\{(9T4)e.W:gzx2e\(9T4)e.jW:gzx2e\(
LTfmw*(:>)DliC_ALTfw*(:">)DliC_ALTw*(:3">)DliCALTw*v(:3">)DliCLTw*v(:h3">)DliCL
1qEAPCH6yX##p04`*1qEPCH6yX##p04`*>1qECH6yX##p04`*>1qhECH6yX##p04`*1qhECH6kyX##p04`*1
[p3s(UUH"4AiD61d[p3(UUH"4AiD61d1[p3(UH"4AiD61d1S[p3(UH"4AiD61d1[p3(UXH"4AiD61d1
Fw3pjB(uKE`:K{tAFw3jB(uKE`:K{tA''Fw3jB(uK`:K{ttA''Fw3jB(uK`:K{ttA''Fw3jB(uK`:K{ttA
BNuU;-DP=S,;.R]ABNuU;-DP=S,;.R]ABNuU;-DP=S,;.R]ABNuU;-DP=S,;.R]ABNuU;-DP=S,;.R]
mJbtBYdN>3t]{zThmJbtBYdN>3t]{zThmJbtBYdN>3t]{zThmJbtBYdN>3t]{zThmJbtBYdN>3t]{zT
tth2$W-h.8N;5.''Ntth2$W-h.8N;5.''Ntth2$W-h.8N;5.''Ntth2$W-h.8N;5.''Ntth2$W-h.8N;5.''
##imlmUeV3]6YZ5my##imlmUeV3]6YZ5my##imlmUeV3]6YZ5my##imlmUeV3]6YZ5my##imlmUeV3]6YZ5m

','

               @              @              @              @
  .GHu>K@i>g@y+$Y.GHu>K@i>g@y+$Y.GHu>K@i>g@y+$Y.GHu>K@i>g@y+$Y.GHu>K@i>g@y+
  yno$]J+hI2g0&O@yno$]J+hI2g0&O@yno$]J+hI20&O@yno$]JJ+hI20&O@yno$]JJ+hI20&O
  |IBOxmr{li^7!NW|IBOxmr{li^7!NW|IBOxm{li^7!NW|IBOxm{li^77!NW|IBOxm{li^77!N
  k0]JwpQ:GxaZ\=>k0]JwpQ:GxaZ\=>k0]JpQ:GxaZ\=>k0]JpQ:GxaZ\==>k0]JpQ:GxaZ\==
  zsHE>{(a.K|Qs\ezsHE>{(a.K|Qs\ezsE>{(a.K|Qs\ezsE>{(a.K|Qs\ezzsE>{(a.K|Qs\e
  )N{dE:kPaN_xbCp)N{dE:kPaN_xbCpN{dE:kPaN_xbCpN{dE:kPaN_xbCpN{ddE:kPaN_xbCp
  ,9nS$e:W<MjCu6'',9nS$e:W<MjCu6,9nS$eW<MMjCu6,9nS$eW<MjCuu6,9nS$$eW<MjCuu6,
  O8!2''dEz##49Nti>O8!2''dEz##49Nt>O8!2''Ez##499Nt>O8!2''Ez##99Nt>>O8!2''EEz##99Nt>>O
  &Sluv_lQnc<)+Xi&Sluv_lQnc<)Xi&SluvlQnc<<)Xi&SluvlQn<<)Xii&SluvlQQn<<)Xii&
  !zO<1:{$]j+,^CX!zO<1:{$]j+,CX!zO<1:$]jj+,CX!zO<1:$]j+,CCX!zO<1:$$]j+,CCX!
  XYJC@=.ohaN/U^CXYJC@=.ohaN/^CXYJC@=.ohaN/^CXYJC@=.ohaN/^CXYJC@=..ohaN/^CX
  {pQZgT!Vk4)2|qz{pQZgT!Vk4)2qz{pQZgT!Vk4)2qz{pQZgT!Vk4)2qz{pQZgT!!Vk4)2qz{
  NoPA^ohY6kt-_h]NoPA^ohY6kt-h]NoPA^ohY6kt-h]NoPA^ohY6kt-h]NoPA^ohhY6kt-h]N
  q>K0Yz?DU&w`&gxq>K0Yz?DU&w`gxq>K0Yz?DU&w`gxq>K0Yz?DU&w`gxq>K0Yz??DU&w`gxq
  tUb_$U.Od-&Ky&otUb_$U.Od-&K&otUb_$U.Od-&K&otUb_$U.Od-&K&otUb_$UU.Od-&K&ot
  Cxm.7pI2O@yf(Y*Cxm.7pI2O@yf(*Cxm.7I2OO@yf(*Cxm.7I2OO@f(**Cxm.77I2OO@f(**C
  v;@1>/0%B_0Iw@!v;@1>/0%B_0Iw@v;@1>/%B_00Iw@v;@1>/%B00Iww@v;@11>/%B00Iww@v
  aRK|MV3d)&7("/0aRK|MV3d)&7("/0aK|MV3d&7("/0aK|MV3d&7(("/0aK||MV3d&7(("/0a
  $evW85:WL%zCQnk$evW85:WL%zCQnk$eW85:WL%zQnk$eW85::WL%zQnk$eeW85::WL%zQnk$
  Gt!bs<m.CHIFT)2Gt!bs<m.CHIFT)2Gt!b<m.CHIFT)2Gt!b<m.CHIFT))2Gt!b<m.CHIFT))
  JcPe^stE6gD1WXeJcPe^stE6gD1WXeJcPe^st6gD1WXeJcPe^st6gDD1WXeJcPe^st6gDD1WX
  ildea<''d!>m<S>gildea<''d!>m<S>gildea<''d!>mS>gildea<S''d!>mS>gildea<S''d!>mS>
  TQn##PA&{h9jKE6STQn##PA&{h9jKE6STQn##PA&{h9jKE6STQn##PA&{h9jKE6STQn##PA&{h9jKE
  
  ','
  
________________________________________________________________________
         /\       /\       /\       /\       /\       /\       /\       /
  \ 3D  /__\   3D/ _\     3D \_    / 3D__   /  \3D_  /  \  3D /  \   _3D
   \   //\ \\   / /\ \   /  /\\\  /   /\ \ /    \\ \/    \/\ /    \ /\/\
  \ \ //::\ \\ / /::\ \ /  /::\\\/   /::\ /    /:\\/\    /\:/ \    \:/\ \
  _\ \/:LS:\_\\ /:LS:\_\  /:LS:\\\  /:LS:\_\  /:LS\\_\  /:LS:\_\  /:LS:\_\
   / /\::::/ // \::::/ /  \::::///  \::::/ /  \:::// /  \::/:/ /  \:/::/ /
  / / \\::/ // \ \::/ / \  \::///\   \::/ \    \://\/    \/:\ /    /:\/ /
   /   \\/_//   \ \/_/   \  \///  \   \/_/ \    //_/\    /\/_\    / \/\/
  / SIG \  /   SIG  /     SIG/     \ SIG    \  /SIG  \  /  SIG\  /    SIG
  _______\/_______\/_______\/_______\/_______\/_______\/_______\/_______\_
  
','
  
 |"""""""i"""""""""""""i"""""""""""""i"""""""""""""i"""""""""""""i"""""""|
 |""3D"""""X"""""3D"""""X"""""3D"""""X"""""3D"""""X"""""3D"""""X"""""3D""|
 |["""""""""]X["""""""""]X["""""""""]X["""""""""]X["""""""""]X["""""""""]|
 |"XXX""SIG"""XXX""SIG"""XXX""SIG"""XXX""SIG"""XXX""SIG"""XXX""SIG"""XXX"|
 |""""XXX"""""""XXX"""""""XXX"""""""XXX"""""""XXX"""""""XXX"""""""XXX""""|
 |X["LS"]XXX["LS"]XXX["LS"]XXX["LS"]XXX["LS"]XXX["LS"]XXX["LS"]XXX["LS"]X|
 |"XXXXX"""XXXXX"""XXXXX"""XXXXX"""XXXXX"""XXXXX"""XXXXX"""XXXXX"""XXXXX"|
 |XXX""XXXXX""XXXXX""XXXXX""XXXXX""XXXXX""XXXXX""XXXXX""XXXXX""XXXXX""XXX|

','

q!)*(&?'';o[}KHB()q!)*(&?'';o[}KHB()q!)*(&?'';o[}KHB()q!)*(&?'';o[}KHB()q!)*(&
tyer(*^%HG68%bkHltyer(*^%HG68%bkHltyer(*^%HG68%bkHltyer(*^%HG68%bkHltyer(*
12?!q3y*@  _._]sf12?!q3y*@  _._]sf12?!q3y*@ _._ ]sf12?!q3y*@ _._ ]sf12?!q3
x!~p;l  ,a8P8Y8a,x!~p;l  ,a8P8Y8a,x!~p;l ,a8P8Y8a, x!~p;l ,a8P8Y8a, x!~p;l
b, ff ,d,  .-.  ,b, ff ,d,  .-.  ,b, ff,d, .-.   ,b,  ff,d, .-.   ,b,  ff,
d"b  d"b  d''I''b  d"b  d"b  d''I''b  d"b d"b d''I''b   d"b  d"b d''I''b   d"b  d"
   ,D,   ,P 8 Y,    ,D,   ,P 8 Y,   ,D   ,P 8 Y,    ,D    ,P 8 Y,    ,D
  ,P P, "d'' 8 ''b"  ,P P, "d'' 8 ''b" ,P P,"d'' 8 ''b"  ,P P ,"d'' 8 ''b"  ,P P ,
 ,P   P,8gcg8gcg8 ,P   P,8gcg8gcg8,P   ,8gcg8gcg8, P   , 8gcg8gcg8, P   , 
,8P"""8P,8P"""8P ,8P"""8P,8P"""8P,8P""8P,8P"""8P,8P"""8P, 8P"""8P,8P"""8P,
d ,a8a, d /\ /\  d ,a8a, d /\ /\ d ,aa, d /\ /\ d ,a8a, d  /\ /\ d ,a8a, d
8,P" "Y,8  ( )   8,P" "Y,8  ( )  8,P""Y,8  ( )  8,P" "Y,8   ( )  8,P" "Y,8
8P''   `Y8.( o ). 8P''   `Y8.( o ).8P''  `Y8.( o ).8P''   `Y8 .( o ).8P''   `Y8
8''/\ /\''8,  _  , 8''/\ /\''8,  _  ,8''/\/\''8,  _  ,8''/\ /\''8 ,  _  ,8''/\ /\''8
8  ( )  8;.(_).; 8  ( )  8;.(_).;8  ()  8;.(_).;8  ( )  8 :.(_).;8  ( )  8
8.( o ).8Ya   aP 8.( o ).8Ya   aP8.(  ).8Ya   aP8.( o ).8 Ya   aP8.( o ).8
8=-=-=-=8 "YaP"  8=-=-=-=8 "YaP" 8=-==-=8 "YaP" 8=-=-=-=8  "YaP" 8=-=-=-=8
Y"""a"""Yaa,,,aa Y"""a"""Yaa,,,aaY""""""Yaa,,,aaY"""a"""Y aa,,,aaY"""a"""Y
 `bag,d''  ``""''''  `bag,d''  ``""'''' `bagd''  ``""'''' `b agd''   ``""'''' `b agd'' 
  `YPY''   ,aaa,    `YPY''   ,aaa,   `YPY   ,aaa,    `YPY''   ,aaa,    `YPY''  
  P "Y  Ya_).(_aY  P "Y  Ya_).(_aY  P"Y  Y_).(_ aY  P" Y  Y_).(_ aY  P" Y 
"'' de `"Y_"" ""_P"'' de `"Y_"" ""_P"'' de`"Y_"" ""_P"''  de`"Y_"" ""_P"''  de`"
 swed @## sf;lks   swed @## sf;lks   swed @## sf;lks   swed @## sf;lks   swed @
fkl*  mproot@mtuzfkl*  mproot@mtuzfkl*  mproot@mtuzfkl* mproot@mtu zfkl* mp
.;uiyhkg&6uiOP98p.;uiyhkg&6uiOP98p.;uiyhkg&6uiOP98p.;uiyhkg&6uiOP98p.;uiyhk

','

      .                    .                    .                    .
      :                    :                    :                    :
      :    .               :    .               :    .               :
     .''   .   .           .''   .   .           .''   .   .           .''   .
    .''   .'' O.''   .      .''   .O  .''   .      .''  O.''  .''   .      .''O  .''
   .''   .''  .''  ..      .''   .''  .''  ..      .''   .''  .''  ..      .''   .''
   ::   :   .O ..       ::   :  O.'' ..       ::   :O  .'' ..       ::  O:
   : \. ''   :  :         \. .''   :  :        \.  .''   :  :       \.   .''
 \,  ;\\,,  :O ''.    \,  ;\\,,  O:  ''.   \,  ;\\,, O :   ''.  \,  ;\\,,O''
  \\::333:o  .  ''''    \\::333:o  ''.  ''''   \\::333:o   ''.  ''''  \\::333:o
 , /:33333:< :  ,      /:33333:<  ,   :    /:33333:<,  ::  :   /:33333:<
  '' ''///''''    .:/     '' ''///''''  .:/   :   '' ''///''''.:/  .''  :  '' ''///'''' ::
     /  :: ,,///;,  ,/   /   ,,///;,  ,/ .:  / ,,///;,  ,/ ''. .: /     ::
       .'' o:33333:://       o:33333::// . :   o:33333:://   ''. :      .''''
      .'' >:3333333:\\      >:3333333:\\ ::   >:3333333:\\    ::      .''  .
     .''    ''''\\\\\" ''\       ''''\\\\\" ''\ :     ''''\\\\\" ''\   ::     .''   :
     ::    ''. '';\  '' ''\   ::    '';\  . ''\ ''    :: '';\ .  ''\ .'' ''    ::
     '':..   '' ,. '''' :     '':..   '' ,.:'''' :     '':..   '' ,.:'''' :     '':..
      :::    .''''   ::      :::    .''''   ::      :::    .''''   ::      :::
      :::  .:'' .  .''       :::  .:'' .  .''       :::  .:'' .  .''       :::
      ::: :::  ::::        ::: :::  ::::        ::: :::  ::::        ::: :
      
','
      
    _( )          _( )         _( )          _( )        _( )   
  _( )  )_      _( )  )_     _( )  )_      _( )  )_    _( )  )_ 
 (____(___)    (____(___)   (____(___)    (____(___)  (____(___)
                                                                
 
   /\          /\           /\          /\         /\        
  /  \  /\    /  \  /\     /  \  /\    /  \  /\   /  \  /\   
 /    \/  \  /    \/  \   /    \/  \  /    \/  \ /    \/  \  
           \/          \ /          \/          /          \/ 
   ..        ..        ..         ..        ..         ..       
"        "         "        "         "         "        "      
    *       *        *       *        *       *       *       *
  @     @      @     @      @      @     @      @     @     @   
 \|/   \|/    \|/   \|/    \|/    \|/   \|/    \|/   \|/   \|/  
 
 ','
 
      /^\           /^\           /^\           /^\           /^\
 ########################################################################################################################################
 ########################################################################################################################################
  /    ########     /   ########\     /  ######## \     / ########  \     /########   \
/       #### \__/      ####  \__/     ####   \__/    ####    \__/   ####     \
   ____ ####     ____  ####    ____   ####   ____    ####  ____     #### ____
  /    \####    /    \ ####   /    \  ####  /    \   #### /    \    ####/    \
 |  2D  |##   |  2D  |####  |  2D  | #### |  2D  |  ####|  2D  |   ##|  2D  |
 |  or  |##   |  or  |####  |  or  | #### |  or  |  ####|  or  |   ##|  or  |
 |  3D  |##   |  3D  |####  |  3D  | #### |  3D  |  ####|  3D  |   ##|  3D  |
 |  ??  |##   |  ??  |####  |  ??  | #### |  ??  |  ####|  ??  |   ##|  ??  |
 |      |    |      |    |      |    |      |    |      |    |      |
 --------    --------    --------    --------    --------    --------
  \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\
   \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\    \\\\\\\\
     \\\\\\      \\\\\\      \\\\\\      \\\\\\      \\\\\\      \\\\\\
     
','     
     
   YoY          YoY          YoY          YoY          YoY          YoY
-=<{Koala}>=-=<{Koala}>=-=<{Koala}>=-=<{Koala}>=-=<{Koala}>=-=<{Koala}>=-
   | |  ___     | |   ___    | |    ___   | |     ___  | |      ___ | |
   |/|{~._.~}   |/| {~._.~}  |/|  {~._.~} |/|   {~._.~}|/|    {~._.~|/|
   | | ( Y )    | |  ( Y )   | |   ( Y )  | |    ( Y ) | |     ( Y )| |
   |/|()~*~()   |/| ()~*~()  |/|  ()~*~() |/|   ()~*~()|/|    ()~*~(|/|
   | |(_)-(_)   | | (_)-(_)  | |  (_)-(_) | |   (_)-(_)| |    (_)-(_| |
   |/|          |/|          |/|          |/|          |/|          |/|
>=-| l RoWaN }>=| l{ RoWaN }>| l<{ RoWaN }| l=<{ RoWaN | l-=<{ RoWaN| l=-
  / o \        / o \        / o \        / o \        / o \        / o \
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

','


`~''   `~^~'' ``~''   `~^~'' ``~''   `~^~'' ``~''   `~^~'' ``~''   `~^~'' ``~''   `~^~'' `
   \/          \/          \/          \/          \/          \/          \/
  \/          \/          \/          \/          \/          \/          \/
   \\         \\/        \\\/       \\ \/      \\  \/     \\   \/    \\    \/
  \,...   \   ,...   \   ,...   \   ,...   \   ,.../  \   ,...\/ \   ,... \/\
\\;::(O;  \\\;::(O;  \\\;::(O;  \\\;::(O;  \\\;::(O;/ \\\;::(O;\/\\\;::(O; \\\\
<{(fishy   <{(fishy/  <{(fishy / <{(fishy  /<{(fishy   <{(fishy/  <{(fishy\/ <{
//^UWU~  \///^UWU~/  ///^UWU~\/ ///^UWU~ \////^UWU~  \///^UWU~/  ///^UWU~\/ ///
  \///  \//   // /  \/   /// /  //  //\/ / /\/ // \/ // \///  \/ /  \//   \///
   \/    \/    \/    \/    \/    \/    \/    \/    \/    \/    \/    \/    \/
  \/      \/  \/      \/  \/      \/  \/      \/  \/      \/  \/      \/  \/
o0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O
0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0O
o0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O0oo0Oo0OOo0O

','

   o                o                o                o                o
 /<.            _ /<.            _ /<.            _ /<.            _ /<.
)>(*)       o  (*)>(*)      o   (*)>(*)     o    (*)>(*)    o     (*)>(*)
        o_ /<.        o  _ /<.      o    _ /<.    o      _ /<.  o
     _ /<.)>(*)    _ /<.(*)>(*)  _ /<.  (*)>(*)_ /<.    (*)>(_)/<.
    (*)>(*)       (*)>(*)       (*)>(*)       (*)>(*)       (*)>(*)
/___\|/___\|/___\|/___\|/___\|/___\|/___\|/___\|/___\|/___\|/___\|/___\|/

','

  .    .   .     .  .    .    .   .     .  .    .    .   .     .  .    .    .
    .    .    .      .     .    .    .      .     .    .    .      .     .    .
 ./\    .   .   /\ .    /\     .   .  /\  .   /\      .   . /\   .  /\.      .
 /  \.        ./  \   ./  \ .        /  \    /  \  .       /  \    /  \   .
/    \ .  /\  /    \  /    \  . /\  /    \. /    \   ./\  /    \ ./    \    /\
      \  /  \/     _\/      \  /  \/    _ \/      \  /  \/   _  \/      \  /  \
    _  \/         (_)    _   \/        (_)    _    \/       (_)    _     \/
   (_)        _    |    (_)        _    |    (_)        _    |    (_)        _
    |        (_)         |        (_)         |        (_)         |        (_)
--------+-----+------------+-------+----------+---------+--------+-----------+-
--------|------------------|------------------|------------------|-------------
                                                                  Mike Elness
________/""||"""""""""""""|_________/""||"""""""""""""|_________/""||""""""""""
._/"\_, |  ||_____________| ._/"\_, |  ||_____________| ._/"\_, |  ||__________
"o---o" ''O--OO       OO OO  "o---o" ''O--OO       OO OO  "o---o" ''O--OO       OO
""""\,   .__/""\__,   .__/"""""\,   .__/""\__,   .__/"""""\,   .__/""\__,   .__
---()"   "()----()"   "()-----()"   "()----()"   "()-----()"   "()----()"   "()
\                 /"""T"""\                 /"""T"""\                 /"""T"""\
_>---\       ,---<____|____>---\       ,---<____|____>---\       ,---<____|____
-/"\ {      / /"\    -|   -/"\ {      / /"\    -|   -/"\ {      / /"\    -|   -
-\_/-=      =-\_/-----+----\_/-=      =-\_/-----+----\_/-=      =-\_/-----+----
_______________________________________________________________________________


','

     .. .-.              .. .-.           .. .-.
   .''  `'' ;   .-''''-.   .''  `'' ;  .-''''-. .''  `'' ;
   `-..,-''   :     ;   `-..,-''  :     ; `-..,-''
              `--/\              `--/\
      /\       /WW;:\  /\         /WW;:\ /\
    /WW;:\ /\/WW;::'' /WW;:\  /\ /WW;::''/WW;:\
  /WWW;;:. \;:\;::''/WWW;;:. \;:.\W;::/WWW;;:. \
< ---===---,--~--.,---===---,---~--.,---===--- >
  \   ~    /~ /    \  ~     / ~ /    \    ~   /
    \  ~ / \/\  ~    \  ~ /  \/ \   ~  \   ~/
      \/       \  ~ /  \/         \  ~ / \/
                 \/                 \/       
                 
','
                 
Dr.           Dr.            Dr.            Dr.          Dr.            Dr.
 H O    *    W H O     *    W H O     *    W H O*    *  W H O  *    *  W H O
 *        *     *        *     *        *     *        *     *        *     *
  \|/  *        \|/   *       \|/    *      \|/     *     \|/      *    \|/
 __^__      *  __^__        *__^__*        __^__ *       __^__  *      __^__
 |##|##|   *     |##|##|   *     |##|##|    *    |##|##|     *   |##|##|      *  |##|##|
 |L|L|     *   |L|L|      *  |L|L|       * |L|L|        *|L|L|*        |L|L|
 |L|L|*        |L|L| *       |L|L|  *      |L|L|   *     |L|L|    *    |L|L|
 |L|L|   *     |L|L|    *    |L|L|     *   |L|L|      *  |L|L|       * |L|L|
 -----      *  -----       * -----*       *----- *       -----  *      -----
Dr.    *       Dr.    *       Dr.    *      Dr.     *       Dr.    *       Dr.
 H O      *   W H O      *   W H O      *  W H O       *   W H O      *   W H O
 
',' 
 
+------+       +------+       +------+       +------+       +------+
|`.    |`.     |\     |\      |      |      /|     /|     .''|    .''|
|  `+--+---+   | +----+-+     +------+     +-+----+ |   +---+--+''  |
|   |  |   |   | |    | |     |      |     | |    | |   |   |  |   |
+---+--+   |   +-+----+ |     +------+     | +----+-+   |   +--+---+
 `. |   `. |    \|     \|     |      |     |/     |/    | .''   | .''
   `+------+     +------+     +------+     +------+     +------+''


   .+------+     +------+     +------+     +------+     +------+.
 .'' |    .''|    /|     /|     |      |     |\     |\    |`.    | `.
+---+--+''  |   +-+----+ |     +------+     | +----+-+   |  `+--+---+
|   |  |   |   | |    | |     |      |     | |    | |   |   |  |   |
|  ,+--+---+   | +----+-+     +------+     +-+----+ |   +---+--+   |
|.''    | .''    |/     |/      |      |      \|     \|    `. |   `. |
+------+''      +------+       +------+       +------+      `+------+

','

+------+       +------+       +------+       +------+       +------+
|`.     `.     |\      \      |      |      /      /|     .''     .''|
|  `+------+   | +------+     +------+     +------+ |   +------+''  |
|   |      |   | |      |     |      |     |      | |   |      |   |
+   |      |   + |      |     |      |     |      | +   |      |   +
 `. |      |    \|      |     |      |     |      |/    |      | .''
   `+------+     +------+     +------+     +------+     +------+''


   .+------+     +------+     +------+     +------+     +------+.
 .''      .''|    /      /|     |      |     |\      \    |`.      `.
+------+''  |   +------+ |     +------+     | +------+   |  `+------+
|      |   |   |      | |     |      |     | |      |   |   |      |
|      |   +   |      | +     |      |     + |      |   +   |      |
|      | .''    |      |/      |      |      \|      |    `. |      |
+------+''      +------+       +------+       +------+      `+------+

','

 |      |      |      |      |      |      |      |      |      |      |
 |------|------|------|------|------|------|------|------|------|------|--
 |      | o__, |       o__,  |      o__,   |     o__,    |    o__,     |
 | o__,--|,>_/-o__,-|--,>_/o__,|----,>_o__| -----,>o_|,--|----,o|_,----|--
   ,>_/-_|x)`\(,>_/-| (x)`\,>_/|_  (x)`,>_|-_   (x),>|/-_    (x,|_/-_
  (x)`\(x|    (x)`\(|)    (x)`\|x)    (x)`|(x)    (x)|\(x)    (x|`\(x)
 --------|----------|----------|----------|----------|----------|---------
 e  Tour | Le  Tour | Le  Tour | Le  Tour | Le  Tour | Le  Tour | Le  Tour
 ________|__________|__________|__________|__________|__________|_________
 ^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^~^
 
 ','
 
          /^\              /^\              /^\              /^\
      _  /   \        _   /   \       _    /   \      _     /   \     _
     / \_     \_     / \_/     \_    / \_ /     \_   / \_  /     \_  / \_
    /    \      \   /    \       \  /    \        \ /    \          /    \
 __/      \      __/      \      __/      \      __/      \      __/      \
   xx      \    /xx        \   xx  \       \ xx /  \       xx   /  \     xx
 x XX     x \_ x XX \    x   x XX   \   x  x XX     \  x x XX _/    \  x XX
 X XX-x-x-XxX--X XX-x--x-XxX-X XX-x---x-XxXX XX-x----x-XxX XX-x-----x- X XX
 XxXX X XxX    XxXX X  XxX   XxXX X   XxX  XxXX X    XxX XxXX X     Xx XxXX
   XXxX __X      XXxX  __X     XXxX   __X    XXxX    __X   XXxX     __   XX
   XX            XX            XX            XX            XX            XX
 __XX      ______XX      ______XX      ______XX      ______XX      ______XX
 
','
 
 (  )            (  )           (  )            (  )           (  ) 
(_,,_)          (_,,_)         (_,,_)          (_,,_)         (_,,_)
  ||              ||             ||              ||             ||  
      ____         ____          ____         ____          ____    
   __/_o|_\_    __/_o|_\_     __/_o|_\_    __/_o|_\_     __/_o|_\_  
  ''-o-----o-''  ''-o-----o-''   ''-o-----o-''  ''-o-----o-''   ''-o-----o-'' 
  
','
  
___  .-~~''.      ___~~-_.-~~''.    ___~  ~~-.-~~''.  ___ -~  ~~-.-~~'' ___
| ''''|`-...--'' ~'' | ''''|  `-...--''  | ''''|    `-...-- | ''''|      `-... | ''''|
|'' ''| -''     '': _|'' ''| ..--''      |'' ''| _....--''   |'' ''| ___....--'' |'' ''|
| ''''|_   _     | | ''''| _   _     || ''''|  _   _     | ''''|   _   _    | ''''|
| ''''| |_| |____| | ''''|| |_| |____|| ''''|_| |_| |____| ''''||_| |_| |___| ''''|
|'''' | | | |    | |'''' || | | |    ||'''' | | | | |    |'''' || | | | |   |'''' |
| ''''|____ |    | | ''''|____  |    || ''''|____ | |    | ''''|____  | |   | ''''|
| '' |'''' ''|_______| '' |'''' ''|_______| '' |'''' ''|_______| '' |'''' ''|_______| '' |
|'' ''|'' '' |''''''''  ''|'' ''|'' '' |''''''''  ''|'' ''|'' '' |''''''''  ''|'' ''|'' '' |''''''''  ''|'' ''|
| '' | ''''''| ''''  ''''| '' | ''''''| ''''  ''''| '' | ''''''| ''''  ''''| '' | ''''''| ''''  ''''| '' |
____  ______________  ______________  ______________  ______________  ___
=||=)(=||===||===||=)(=||===||===||=)(=||===||===||=)(=||===||===||=)(=||
##################################################################################################################################################
| \\##//  |'''' ''''''  \\##//   |'''' '''''' \\##//    |'''' '''' \\##//     |'''' '' \\##//
|'' |##| ''''| ''''''''  | |##|  ''''| ''''''''   |##|   ''''| ''''''''  |##| |  ''''| '''''''' |##| ''|
|''''|##| '' |''''''   ''|''|##| '''' |''''''   '' |##| '''''' |''''''    |##|''|'''''' |''''''   |##| ''|
|'' |##|  ''| ''  '''' |''|##| '' ''| ''  ''''  |##|  '' ''| ''  '''' |##|''| '' ''| ''  '' |##| ''|
   |##|             |##|             |##|             |##|             |##|
   
','  
   
According    to    the  According    to    the
police      inspector,  police      inspector,
Edward  John Billings,  Edward John  Billings,
there  are   too  many  there  are   too  many
individuals  too close  individuals  too close
to  the  case to  make  to  the  case to  make
an  arrest.   I  asked  an  arrest.   I  asked
Mary  Smith to comment  Mary Smith  to comment
on  the case,  but she  on  the case,  but she
declined  to  comment,  declined  to  comment,
because  she  is  soon  because  she is   soon
to   be   married   to  to   be   married   to
Howard  D. Fredericks,  Howard  D. Fredericks,
the   victim''s  uncle.  the   victim''s  uncle.
Charles   Wilson,  the  Charles   Wilson,  the
victim''s      brother,  victim''s      brother,
stated that  the chaos  stated that  the chaos
was   responsible  for  was  responsible   for
at least  five suicide  at least  five suicide
attempts   last   week  attempts   last   week
alone.                  alone.                

','

___|______|______|______|______|______|______|______|______|______|______|______
=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3D*St=>3
ereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piereo!Piere
cture+Tcture+Tcture+Tcture+Tcture+Tcture+Tcture+Tcture+Tcture+Tcture+Tcture+Tctu
ext^=>3ext^=>3ext^=>3ext^=>3ext^=>3ext^=>3xt^=>3xt^=>3xt^=>3xt^=>3xt^^=>3xt^^=>3
D*StereD*StereD*StereD*StereD*StereD*Stere*Stere*Stere*Stere*Stere*Sttere*Sttere
o!Pictuo!Pictuo!Pictuo!Picto!Picto!!Picto!PictoPictoPictoPPictoPPictooPPictooPPi
re+Textre+Textre+Textre+Tetre+Tetre+TTetreTTetrTTetrTTetrTTeetrTTeetrrTTeetrrTTe
^=>3D*S^=>3D*S^=>3D*S^=>3*S^=>33S^=>333S^=333S^333S^333S^333S^^333S^^^333S^^^333
tereo!Ptereo!Ptereo!Ptero!Pteero!teero!!tero!!ter!!terr!terr!terrr!teerrr!teerrr
icture+icture+icture+ictre+icctre+ictree+itree+itee+ittee+itee+iitee++iitee++iit
Text^=>Text^=>Text^=>Text^=>Text^=Text^^=Txt^^=Tx^^=Txx^^=Tx^^=TTx^^==TTx^^==TTx
3D*Ster3D*Ster3D*Ster3D*SterD*SterD*StterDStterDSterDSSterDSterDSSterrDSSterrDSS
eo!Picteo!Picteo!Picteo!Picto!Picto!PiictoPiictoPictoPPictoPictoPPicttoPPicttoPP
ure+Texure+Texure+Texure+Texre+Texre+TTexr+TTexr+Texr++Texr+Texr++Texxr++Texxr++
t^=>3D*t^=>3D*t^=>3D*t^=>3D*t^=>3Dt^=>33Dt=>33Dt=33Dt==33Dt=33Dtt=33DDtt=33DDtt=
Stereo!Stereo!Stereo!Steeo!Stteeo!Steeoo!Seeoo!Seoo!Seeoo!Seoo!SSeoo!!SSeoo!!SSe
PicturePicturePicturePicurePiicurPiicurrPicurrPicrrPiccrriccrriiccrriiiccrriiicc
+Text^=+Text^=+Text^=+Tex^=+Tex^=+Tex^^=+Tx^^=+x^^=+x^^=+x^^=++x^^=+++x^^=+++x^^
>3D*Ste>3D*Ste>3D*Ste>3D*Se>3D*Se>3DD*Se>3D*Se>D*Se>D*Se>D*SSe>D*SSe>>D*SSe>>D*S
reo!Picreo!Picreo!Picreo!Pireo!Pireeo!Pireo!Piro!Piro!Piro!!Piro!!Pirro!!Pirro!!
ture+Teture+Teture+Teture+Teture+Teture+Teure+Teure+Teure+Teure+Teuree+Teuree+Te
xt^=>3Dxt^=>3Dxt^=>3Dxt^=>3Dxt^=>3Dxt^=>3Dt^=>3Dt^=>3Dt^=>3Dt^=>3Dt^==>3Dt^==>3D
*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*Stereo*St
!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pictur!Pi
e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+Text^e+T
___|______|______|______|______|______|______|______|______|______|______|______

','

Blue Skies  Blue Skies Blue Skies  Blue Skies  Blue Skies  Blue Skies  
uds  /\  clouds  /\  clouds  /\  clouds /S\  clouds /S\ clouds e/S\ clou
d  /(o)\ bird  /(o)\birdu  /(o)\birdu /(o)\ birdu /(o)\ birdu /(o)\ bird
 /Pyramid\   /Pyramid\   /Pyramid\  /Pyramid\i  /Pyramid\i  /Pyramid\i  
\ Pharaon  A\ Pharaon  A\ Pharaon A\ Pharaon A\  Pharaon A\  Pharaon A\ 
es\Magic0^Eyes\Magic0^Eyes\Magic^Eyes\Magic^Eyes\PMag^o^Eyes\PMag^o^Eyes
King\M@/The King\M@/The King\M/The King\M/The King\aThe^e King\aThe^e Ki
gypt /Of 0^Egypt /Of^h^Egypt/Of^h^Egypt/Of^h^EgyptOf^h^Eg gyptOf^h^Eg gy
Go ld-$Op/x\Go ld-$/x\^\Gold-$/x\^\Gold/x\^\^\God/x\^\^\Godyd/x\^\^\Gody
yrmidFG/-_\Pyrmid/-_\Pyromid/-_\Pyromi-_\Pyro\mi-_\Pyro\mi-_\/\Pyro\mi-_
ro^@6A/\Cairo^@A/\Cairo^@Ai/\Cairo^@/\Cairo^@/\iCai^y^@/\iCai^yP^@/\iCai
za/##-%/\Giza/##-%/\Giza/##-%/\Giza/##-/\Giza/##-/\Giz/##-/\@\Giz/##-/\@\Giz/##-
PYRAMID)(PYRAMID)(PYRAMID)(PYRAMID)(PYRAMID)(PYAMID)(PYAiMID)(PYAiMID)(P
_/`~-*\._/`~-*\._/`~-*\._/`~-*\._/`~-*\._/`~-*\._/`~-*\._/`~-*\._/`~-*\.
3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3Dimka 3D

','

I  (`\/`) I  (`\/`) I  (`\/`) I  (`\/`) I  (`\/`) I  (`\/`) 
OVE \  / LOVE \  / LOVE \  / LOVE \  / LOVE \  / LOVE \  / L
OU   \/  YOU   \/  YOU   \/  YOU   \/  YOU   \/  YOU   \/  Y
/`)  I (`\/`)  I (`\/`  I (`\Y/`  I (`Y/`  I \(`Y/`  I \(`Y/
  / LOVE \  / LOVE\  / LOVE\  / `LVE\  / `LVE\  /Y `LVE\  /Y
 /  YO U   /  YOU   /  YOU   /  YOU   /  YOU   /  Y`OU   /  
 I (` \/`) I (`\/`) I (`\/`) I (`\/`) I(`\/`)  I(`\/ `)  I(`
LOVE\   / LOVE\  / LOVE\  / LOVE\  / LOV\  /  LOV\  //  LOV\
YOU   \/  YOU  \/  YOU  \/  YOU  \/  YOU \/   YOU \/    YOU 
/`)  I (`\/`)  I(`\/`)  I(`\/`)  I(`\/`)  I(`\/`)  \I(`\/`) 
 / LOVE\   / LOVE\  / LOVE\  / LOVE\  / LOVE\  / )LOVE\  / )
    YOU \/    YOU \/   YOU \/   YOU \/   YOU \/    YOU \/   
I  (`\/`) I  (`\/`) I (`\/`) I (`\/`) I (`\/` ) I (`\/` ) I 
OVE\   / LOVE\   / LOVE\  / LOVE\  / LOVE\ \ / LOVE\ \ / LOV
OU  \/   YOU  \/   YOU  \/  YOU  \/  YOU E \/  YOU E \/  YOU
/`)  I (`\/`)  I (`\/`)  I (\/`)  I (\/O`)  I (\/O`)  I (\/O
  / LOVE \  / LOVE \  / LOVE \ / LOVE( \ / LOVE( \ / LOVE( \
 /  YO U   /  YO U   /  YO U   / YO  U   / YO  U   / YO  U  
I  (`\/`) I  (`\/`) I (`\/`)  I (`\/`) I  (`\/`) I  (`\/`) I
OVE \  / LOVE \  / LOVE\  /  LOVE\  / LOVE \  / LOVE \  / LO
OU   \/  YOU   \/  YOU  \/   YOU  \/  YOU   \/  YOU   \/  YO
by 3Dimka by 3Dimka by 3Dimka by 3Dimka by 3Dimka by 3Dimka 

','

_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%
$(+_~*:)= $(+_~*:)= $(+_~*:)= $(+_~*:)= $(+_~*:)= 
(*)~/^=$_ (*)~/^=$_ (*)/^=$_ (*)/^=$:_ (*)/^=$:_ (
[smile] :)[smile] :)smile] :)smile] :)s(mile] :)s(
 O_o @LOL  O_o @LO  O_o @LO  O_o @LO  O_oi @LO  O_
_~*(:=$(+%_~*(:=$+%_~O*(:$+%_~O*(:@$+%~O*( :@$+%~O
$(+_~*:)= $(+_~*)= $(~+_~)= $(~+_~:)= (~+_~::)= (~
(*)~/^=$_ (*)~/=$_ (*)~/=$_ (*)~/=$_ (*)~/=$:_ (*)
[smile] :)[smil] :)[smil] :)[smil] :)[smil] $:)[sm
 O_o @LOL  O_o LOL  O_o LOL  O_o LOL  O_o LO L  O_
_~*(:=$(+%_~*(:=(+%_ ~*(=(+%_ ~*(=(O+%_~*(=L(O+%_~
$(+_~*:)= $(+_~*:= $(+*_~*:= $(+*_~*: $(+*(_~*: $(
(*)~/^=$_ (*)~/^=$_(*)~/~^=$_(*)~/^=$_(*()~/^=$_(*
[smile] :)[smile] :)smile] :)smile] :)s(mile] :)s(
 O_o @LOL  O_o @LOL  O_ @LOL  O_ @LO L  O_ @LO L  
_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%
by 3Dimka by 3Dimka by 3Dimka by 3Dimkaby 3Dimka b
_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%_~*(:=$(+%

','

pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.
ramid A PIramid A PIramid A PIramid A PIramid A PIramid A PIramid A PIramid A 
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)_~*/=$(+)_~*/=$(+)_~*/=$(+)_~*/r=$(+)_~*/r=$(+)_~
pyramid.A pyramid.A pyraid.A pyraid.A pyraid.A pyraid.A pyra/id.A pyra/id.A py
ramid A PIramid A PIrami A PIami A PIami A PIami A PIam i A aPIam i A aPIam i 
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)~*/=$(+)~*/=$(+)~*/=$(+)~*m/=$( +)~*m/=$( +)~*m/=
pyramid.A pyramid.A pyraid.A yraidA yraidA yraidA$ yrai*dA$ (yrai*dA$ (yrai*dA
ramid A PIramid A PIrami A PIami APIami APIami APAIami iAPAI ami iAPAI ami iAP
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)~*/=$+)~*=$+)~*=i$+)P~*=i$ +)P~I*=i$ +)P~I*=i$ +)
pyramid.A pyramid.A pyraid.A yraidA yridA yri=dA )yri=d$A )y~ri=d$A )y~ri=d$A 
ramid A PIramid A PIrami A PIami APIam APIam iAPI am iAdPI aym iAdPI aym iAdPI
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)~*/=$+)~*=$+)~*= $+)I~*= $A+)I~a*= $A+)I~a*= $A+)
pyramid.A pyramid.A pyraid.A yraidA yraidA yraidA) yrai$dA) ~yrai$dA) ~yrai$dA
ramid A PIramid A PIrami A PIami APIami APIami APAIami iAPAI ami iAPAI ami iAP
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)~*/=$(+)~*/=$(+)~*/=$(+)~* /=$(I+)~* /=$(I+)~* /=
pyramid.A pyramid.A pyraid.A yraid.A yraid.A yraid.A yr*aid.(A yr*aid.(A yr*ai
ramid A PIramid A PIrami A PIrami A PIrami A PIrami A PIrami. A PIrami. A PIra
_~*/\=$(+)_~*/\=$(+)_~*/=$(+)_~*/=$(+)_~*/=$(+)_~*/=$(+)_~*/i=$(+)_~*/i=$(+)_~
pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.
ramid A PIramid A PIramid A PIramid A PIramid A PIramid A PIramid A PIramid A 
pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.
by 3Dimka by 3Dimka by 3Dimka by 3Dimka by 3Dimka by 3Dimkaby 3Dimka by 3Dimka 
pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.A pyramid.

','

erry save blueberry save blueberry save blueberry save blueberry save blueberry
en handful eleven handful eleven handful eleven handful eleven handful eleven h
electricity me electricity me electricity me electricity me electricity me ele
grandfather ma grandfather ma grandfather ma grandfather ma grandfather ma gra
ef a handkerchief a handkerchief a handkerchief a handkerchief a handkerchief a
essness a carelessness a carelessness a carelessness a carelessness a carelessn
kater stop um skater stop um skate stop hum skate stop hum skate stop hum skate
ear in wasting ear in wasting ear i wasting pear i wasting pear i wasting pear 
p tablet your up tablet your up table your cup table your cup table your cup ta
raise law time raise law time raise la time praise la time praise la time prais
i uh not beard i uh not beard i uh not beard i uh not beard i uh not beard i u
h get each tooth get each tooth get each tooth get each toot get peach toot get
ger a one stranger a one stranger a one stranger a one strange a gone strange a
top life alley top life alley top life alley top life alley to life valley to 
er do grasshopper do grasshopper do grasshopper do grasshopper do grasshopper d
sgiving a thanksgiving a thanksgiving a thanksgiving a thanksgiving a thanksgiv
erturn ah on overturn ah on overturn ah on overturn ah on overturn ah on overtu
ook i noon do hook i noon do hook i noon do hook i noon do hook i noon do hook 
ky cabinet whisky cabinet whisky cabinet whisky cabinet whisky cabinet whisky c
i i a fourteen i i a fourteen i i a fourteen i i a fourteen i i a fourteen i i 
ed tin ow slipped tin ow slipped tin ow slipped tin ow slipped tin ow slipped t
ow eve six window eve six window eve six window eve six window eve six window e
my an campfire my an campfire my an campfire my an campfire my an campfire my a

'];

		return images[ min( day( now() ), 30 ) ];
		
	}

}

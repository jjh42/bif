<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<?php

require ('navbar.inc');

// common.php. This is the header that is included by all the other pages.
// The two most important functions are
// common_start and common_end which are included at the beginning and end (du)
// of all the other php pages.

// Emit generic junk at the beginning
function common_start ($title,$extraheader = "") {
	?>



<!--- This is the start of the common header --->




		<html>
		<head>
	<?php
	// Put title in
	echo "\t<title>$title</title>\n";
	?>
		<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
		<!-- Enable the favourites icon -->
		<LINK REL="SHORTCUT ICON" HREF="favicon.ico">
	<?php
	// Put extra stuff in
	if ($extraheader != "")
		echo $extraheader + "\n";
	?>
	</head>
	<body bgcolor="black" text="Lime" link="Green" alink="White">


	<!-- Project bif logo -->
	<a href="index.php">
	<img src="projectbif.png" width="738" height="163" border="0" alt="Project Bif Logo">
	</a>
	<br>
	<!-- Top table contains sf logo and nav panel. -->
	<table width=100%>
  	<tbody>
   	<tr>
      		<td width=100%> <!-- Nav bar -->
			<?php	do_navbar(); ?>
		</td>
  		<td align="right" width=0%>	<!-- Sourceforge logo -->
			<a href="http://sourceforge.net">
				<img src="http://sourceforge.net/sflogo.php?group_id=61715&amp;type=7" width="210" height="62" border="0" alt="SourceForge.net Logo">
			</a>
		</td>
    	</tr>
  	</tbody>
	</table>

<hr>
<a name = "top"> </a>


<!--- This is the end of the common header ---->




	<?php

}

function common_end($id) {
?>



<!--- This is the start of the common footer ---->


	<br><br><br>
	<hr>
	<small>
	<div align="center">

		<a href="#top" >To top of page</a>
		<br>

		If you are having problems with site, have found a spelling mistake or just want to moan please contact the <a href="mailto:jhuntnz@users.sourceforge.net?subject=Problems with bif site">webmaster
			</a>
		<br>
		CVS id <?php echo $id ?>
	</div>
	</small>
	</body>
	</html>



<!--- This is the end of the common footer --->



<?php

}

?>


<?php

// patches.php

require ('common.inc');

common_start("Patches");

?>


<H1> Patches </H1>

<p>
This page contains patches or minor improvements for other programs.
We make no guarantee as to how great these patches are. There aren't very many
at the moment but we will be adding more as they come up.
</p>


<H3> Cervisia patch </H3>
31 October 2002
<p>
Cervisia is a KDE frontend to cvs. I use this program a fair amount and one thing that bugged
me was the way the ChangeLog dialog was modal so I couldn't do diffs on files to see what I
had changed when I was adding entry to the ChangeLog. This patch makes the ChangeLog modeless
so you can do other stuff as well. The patch is against Cervisia version 1.5Rich2. It has
been submitted to the cervisia maintainer.
<br>
To apply you'll need the cervisia source (which you can checkout from the KDE CVS server).
Change to the cervisia directory and apply <a href="stuff/cervisia.patch">this patch</a>.
</p>

<H3> Portage Packages </H3>
30 October 2002
<p>
Since I run Gentoo Linux and do some development for microcontrollers and other strange stuff
it isn't unusual to come across strange programs that I want to install on my computer. When
I have time I make a portage install file (which are really easy to make.) I usually submit
these to Gentoo but it has a bit of a waiting list. Right now I have ebuilds for the following
packages: <BR>
<ul>
<li><a href="http://cook.sourceforge.net">Cook Preprocessor</a></li>
<li><a href="http://sources.redhat.com/binutils"> GNU Binutils for the AVR</a></li>
<li><a href="http://khrono.sourceforge.net">Khrono</a> - a KDE Stopwatch Application</li>
</ul>

See <a href="portage/README"> the README </a> for more info on how to use these ebuilds.
</p>

<H3> Portage Size </H3>
25 October 2002
<p>
If you happen to use Gentoo Linux (like I do) you will probably like it. And "emerge *" is great
but if you're like me and downloading over a 56K modem and would like to know how much downloading
a package is going to take then this patch is for you. When doing emerge -p packagename it prints
out how much downloading each package is going to take and then prints a total at the bottom.
This patch has been submitted to Gentoo Linux.
</p>
<p>
There are 3 patch files for this.
<br>
	<a href="stuff/emergesize/portage.py.patch"> Patch for portage.py </a>
  	which should be in /usr/lib/python*/site-packages/.
<br>
	<a href="stuff/emergesize/output.py.patch"> Patch for output.py. </a>
  	which should be in /usr/lib/python*/site-packages/.
<br>
	<a href="stuff/emergesize/emerge.patch"> Patch for emerge </a> which should
  	be in /usr/lib/portage/.
<br>
After patching these 3 files type emerge -p "something" and you should see sizes showing
up next to each package.

<H3> Kate Syntax Highlighting for AVR assembly language </H3>
20 October 2002
<p>
Kate is a really neat text editor that you can find at <a href="http://kate.kde.org">
http://kate.kde.org </a> which has syntax highlighting. This hightlighting is configurable
with XML files. I made one for highlighting AVR assembly language. Copy
<a href="stuff/avrassembly.xml"> avrassembly.xml </a> into $KDEPREFIX/share/apps/kate/syntax/
and restart kate and then you should be able to get assembly language highlighting. This also
gives kwrite and kdevelop syntax hightlighting for it as well.
</p>


<?

common_end("\$Id: patches.php,v 1.3 2002/11/06 05:00:57 jhuntnz Exp $");

?>

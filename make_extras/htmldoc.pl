use strict;
use Pod::HtmlEasy;
use File::Spec;
use File::Path;
use File::Slurp;

my $podhtml = Pod::HtmlEasy->new() ;

foreach my $file (@ARGV) {
  -f $file or next;
  
  my $html_file = $file;
  $html_file =~ s{\.(pm|pod)$}{\.html} or next;
  $html_file =~ s{blib/lib/|^}{htmldoc/} or next;

  if ( -f $html_file and -M $html_file < -M $file ) {
    print "Skip $file (unchanged)\n";
    next;
  }
  
  print "HTMLifying $file\n";
  my $content = $podhtml->pod2html( $file ) or next;

  $content =~ s{\Q<b>*</b></li>\E\n(\Q<p>\E)?}{}g;

  my $path = $html_file;
  $path =~ s{/[^/]*$}{};
  mkpath( $path );
  write_file( $html_file, $content );
}

########################################################################

my @files = grep {$_ !~ /index/} split "\n", qx! find htmldoc -name '*.html' !;
s{htmldoc/}{} foreach @files;
s{.html?$}{} foreach @files;
my $links = join "<br>", map { my $x = $_; $x =~ s{/}{::}g; qq|<a href="$_.html">DBIx::$x</a>| } 
sort { ( $a =~ /^\Q$b\E./ ) ? 1 : ( $b =~ /^\Q$a\E./ ) ? -1 : ( $a cmp $b ) } @files;

########################################################################

write_file( 'htmldoc/index.html', <<"." );

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html><head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<meta name="GENERATOR" content="Pod::HtmlEasy/0.04 Perl/5.006001 [darwin]">
<title>SQLEngine.pm</title>
<style type="text/css">
<!--

BODY {
  background: white;
  color: black;
  font-family: arial,sans-serif;
  margin: 0;
  padding: 1ex;
}
TABLE {
  border-collapse: collapse;
  border-spacing: 0;
  border-width: 0;
  color: inherit;
}
IMG { border: 0; }
FORM { margin: 0; }
input { margin: 2px; }
A.fred {
  text-decoration: none;
}
A:link, A:visited {
  background: transparent;
  color: #006699;
}
TD {
  margin: 0;
  padding: 0;
}
DIV {
  border-width: 0;
}
DT {
  margin-top: 1em;
}
TH {
  background: #bbbbbb;
  color: inherit;
  padding: 0.4ex 1ex;
  text-align: left;
}
TH A:link, TH A:visited {
  background: transparent;
  color: black;
}
A.m:link, A.m:visited {
  background: #006699;
  color: white;
  font: bold 10pt Arial,Helvetica,sans-serif;
  text-decoration: none;
}
A.o:link, A.o:visited {
  background: #006699;
  color: #ccffcc;
  font: bold 10pt Arial,Helvetica,sans-serif;
  text-decoration: none;
}
A.o:hover {
  background: transparent;
  color: #ff6600;
  text-decoration: underline;
}
A.m:hover {
  background: transparent;
  color: #ff6600;
  text-decoration: underline;
}
table.dlsip     {
  background: #dddddd;
  border: 0.4ex solid #dddddd;
}
.pod PRE     {
  background: #eeeeee;
  border: 1px solid #888888;
  color: black;
  padding-top: 1em;
  white-space: pre;
}
.pod H1      {
  background: transparent;
  color: #006699;
  font-size: large;
}
.pod H2      {
  background: transparent;
  color: #006699;
  font-size: medium;
}
.pod IMG     {
  vertical-align: top;
}
.pod .toc A  {
  text-decoration: none;
}
.pod .toc LI {
  line-height: 1.2em;
  list-style-type: none;
}

--></style>
</head>
<body alink="#FF0000" bgcolor="#FFFFFF" link="#000000" text="#000000" vlink="#000066"><a name='_top'></a>

$links

</body></html>
.

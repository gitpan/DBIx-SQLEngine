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
<title>HTML Doc for SQLEngine</title>
<style type="text/css">
<!--

BODY {
  background: white;
  color: black;
  font-family: arial,sans-serif;
  margin: 0;
  padding: 1ex;
}
A:link, A:visited {
  background: transparent;
  color: #006699;
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

<h1> HTML Doc for SQLEngine </h1>

$links

</body></html>
.

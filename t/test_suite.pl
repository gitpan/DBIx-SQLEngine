#!perl

my $separator = ( '=' x 79 ) . "\n";

my @dsns = grep $_, split "\n", <<'.';
dbi:mysql:test:blackdart
dbi:AnyData:test_data
dbi:SQLite:dbname=t/test_data/test.sqlite
dbi:CSV:f_dir=t/test_data
.

system qq! make !;

print $separator;
system qq! perl -Mblib -MTest::Harness=runtests -e '\$ENV{DBI_DSN}=""; runtests grep { /user_dsn/ ? 0 : 1 } \@ARGV' t/*.t !;

foreach my $dsn ( @dsns ) {

  print $separator;
  my $result = qx! perl -Mblib -MTest::Harness=runtests -e '\$ENV{DBI_DSN}="$dsn"; \$ENV{DBI_DSN_WARN_SUPR}="1"; runtests "t/user_dsn.t"' !;
  print( ( $result =~ /\n(All tests successful.*?\n|Failed.*\Z)/s )[0] || $result );

}

print $separator;

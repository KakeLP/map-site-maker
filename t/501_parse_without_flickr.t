use strict;
use MapSite;
use Test::More tests => 1;

my %data;

eval {
  %data = MapSite->parse_datafile(
                                   file          => "t/data/501.yaml",
                                   check_flickr  => 0,
                                 );
};

ok( !$@, "parse_datafile doesn't die when check_flickr is false" );
diag "Error is: $@" if $@;



use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 3;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my $mapsite = MapSite->new( conf_file => "conf/302.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/list.html" );
like( $html,
      qr/nfe-0252\.html.*nfe-0253\.html/s,
      "Sorting by ID seems to work." );

$mapsite = MapSite->new( conf_file => "conf/302a.conf" );
$mapsite->generate_site;
$html = read_file( "site/list.html" );
like( $html,
      qr/nfe-0253\.html.*nfe-0252\.html/s,
      "...and doesn't seem to have broken sorting by name" );

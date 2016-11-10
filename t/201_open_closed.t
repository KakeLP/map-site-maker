use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 5;

my $mapsite = MapSite->new( conf_file => "t/conf/201.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/map.html" );

tag_ok( $html, "li", { class => "open" }, "we have an <li> for an open venue");
tag_ok( $html, "li", { class => "closed" }, "...ditto for closed" );

like( $html, qr/function\s+add_open_markers.*222-veggie-vegan-restaurant-west-brompton.*add_marker.*function\s+add_closed_markers/s, "add_open_markers() picks up an open venue" );
like( $html, qr/function\s+add_closed_markers.*amico-bio-new-oxford-street/s, "add_closed_markers() picks up a closed venue" );

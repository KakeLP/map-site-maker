use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 6;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my $mapsite = MapSite->new( conf_file => "conf/602.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;
my $html = read_file( "site/map.html" );
no_tag( $html, "a", { id => qr/\bhide_all_cats\b/ },
        "hide_all_cats link absent by default" );

$mapsite = MapSite->new( conf_file => "conf/602a.conf" );
eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;
$html = read_file( "site/map.html" );
no_tag( $html, "a", { id => qr/\bhide_all_cats\b/ },
        "...also absent when show_hide_all_cats_link set to 0" );

$mapsite = MapSite->new( conf_file => "conf/602b.conf" );
eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;
$html = read_file( "site/map.html" );
tag_ok( $html, "a", { id => qr/\bhide_all_cats\b/ },
        "...but present when show_hide_all_cats_link set to 1" );
print $html;

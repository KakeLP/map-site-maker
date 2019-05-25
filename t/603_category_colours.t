use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 5;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my $mapsite = MapSite->new( conf_file => "conf/603.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/map.html" );
tag_ok( $html, "li", { id => "cat_bok", class => qr/\bcat_colour_ltgreen\b/ },
        "category colours correctly applied to catlist on map" );
tag_ok( $html, "li", { id => "cat_bok", class => qr/\bcat_decor_dot\b/ },
        "category decorations correctly applied to catlist on map" );

$html = read_file( "site/list.html" );
tag_ok( $html, "td", { class => qr/\bcat_colour_ltgreen\b/ },
        "category colours correctly applied to list view" );
tag_ok( $html, "div", { class => qr/\bcat_decor_dot\b/ },
        "category decorations correctly applied to list view" );

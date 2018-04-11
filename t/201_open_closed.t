use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 9;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my $mapsite = MapSite->new( conf_file => "conf/201.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/map.html" );

tag_ok( $html, "li", { class => qr/\bcat_open_item\b/ },
        "we have an <li> for an open venue");
tag_ok( $html, "li", { class => qr/\bopen\b/ }, "...and the legacy class" );
tag_ok( $html, "li", { class => qr/\bcat_closed_item\b/ },
        "we have an <li> for a closed venue");
tag_ok( $html, "li", { class => qr/\bclosed\b/ }, "...and the legacy class" );

like( $html,
      qr/function\s+create_all_markers.*222-veggie-vegan-restaurant-west-brompton.*function\s+show_all_markers/s,
      "create_all_markers() picks up an open venue" );
like( $html,
      qr/function\s+create_all_markers.*amico-bio-new-oxford-street.*function\s+show_all_markers/s,
      "...and a closed one" );

like( $html,
      qr/function\s+show_all_markers.*show_category_markers\([^}]+\"open/s,
      "show_all_markers() shows open venues" );
like( $html,
      qr/function\s+show_all_markers.*show_category_markers\([^}]+\"closed/s,
      "...and closed ones" );


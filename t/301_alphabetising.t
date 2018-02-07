use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 5;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my $mapsite = MapSite->new( conf_file => "conf/301.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/list.html" );
like( $html,
      qr/love-gift-vegan-honor-oak-park.html.*love-and-scandal-waterloo/s,
      "'And' ignored in sorting." );
like( $html,
      qr/the-fields-beneath-kentish-town.*food-for-thought-covent-garden/s,
      "...so is 'The'." );
like( $html, qr/andu-cafe-dalston.html.*beatroot-soho.html/s,
      "Things starting with 'And' are sorted correctly." );
like( $html, qr/only-parathas-queensbury.html.*thenga-cafe-bloomsbury.html/s,
      "...so are things starting with 'The'." );

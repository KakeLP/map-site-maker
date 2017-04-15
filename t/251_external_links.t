use strict;
use File::Slurp;
use MapSite;
use MapSite::Utils;
use Test::HTML::Content;
use Test::More tests => 9;

# Run in the t/ directory because otherwise our template extraction below
# may overwrite files that are being worked on.
chdir "t";

my %data;

eval {
       %data = MapSite->parse_datafile(
           file => "data/251.yaml",
           conf_file => "conf/251.conf",
       );
};
ok( !$@, "parse_datafile doesn't die when we have external links" );
diag "Error is: $@" if $@;

my $entity = $data{entities}[0];
ok( $entity->has_links, "...we can see we have external links" );
ok( $entity->links, "...we can access them" );
is( $entity->links->{"WhatPub entry"}, "https://whatpub.com/pubs/CRO/11539/",
    "...we seem to be getting them right" );

$entity = $data{entities}[1];
ok( !$entity->has_links, "...we can also see when we have no external links" );

my $mapsite = MapSite->new( conf_file => "conf/251.conf" );

# Extract the templates.
MapSite::Utils->upgrade_site || die $MapSite::Utils::errstr;

eval { $mapsite->generate_site || die $MapSite::Generate::errstr; };
ok( !$@, "can generate a site from our test data" );
diag "Error is: $@" if $@;

my $html = read_file( "site/venues/dog-and-bull.html" );
tag_ok( $html, "tr", { class => "entity_links" },
        "...we have a links section" );

tag_ok( $html, "a", { href => "https://whatpub.com/pubs/CRO/11539/" },
        "we have a link to WhatPub" );
like( $html, qr/WhatPub entry/,
      "...and the full title of the site is mentioned" );

use strict;
use Config::Tiny;
use MapSite;
use Test::More;

plan tests => 10;

my %data = MapSite->parse_datafile(
                                    conf_file => "t/conf/601.conf",
                                    file => "t/data/601.yaml",
                                  );
my $categories = $data{categories};
my @cat_ids = map { $_->{id} } @$categories;
is_deeply( \@cat_ids, [ qw( closed demolished fabulous open ) ],
           "Correct categories picked up from datafile, including default" );
my @entities = @{$data{entities}};
is( $entities[0]->category, "open", "...open entity has correct category" );
is( $entities[2]->category, "closed", "...so does closed" );
is( $entities[3]->category, "demolished", "...so does demolished" );
is( $entities[1]->category, "fabulous",
    "...entity with no category picks up specified default" );

%data = MapSite->parse_datafile(
                                 file => "t/data/601a.yaml",
                               );
$categories = $data{categories};
@cat_ids = map { $_->{id} } @$categories;
is_deeply( \@cat_ids, [ qw( closed open ) ],
           "Correct categories also picked up when in legacy format" );
@entities = @{$data{entities}};
is( $entities[0]->category, "open", "...open entity has correct category" );
is( $entities[2]->category, "closed", "...so does closed" );
is( $entities[1]->category, "open",
    "...entity with no category picks up default default" );

%data = MapSite->parse_datafile(
                                 file => "t/data/601b.yaml",
                               );
$categories = $data{categories};
@cat_ids = map { $_->{id} } @$categories;
is_deeply( \@cat_ids, [ qw( cafe theatre ) ],
           "Spurious 'open' category not added when no defaults required" );

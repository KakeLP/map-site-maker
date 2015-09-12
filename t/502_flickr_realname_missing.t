use strict;
use Config::Tiny;
use File::Path qw( make_path remove_tree );
use Flickr::API2;
use MapSite;
use Test::More;

# This test requires a Flickr key and secret, which should be stored in a
# config file as they would be for the live site.  Look for an environment
# variable that gives the location of this file - if none set, or if the
# file doesn't exist or isn't readable by this user, just skip the test.
# Also skip the test if the Flickr key/secret aren't valid.

my $flickr_conf_file = $ENV{MAPSITE_FLICKR_CONF};
plan skip_all => "MAPSITE_FLICKR_CONF environment variable not set"
  unless $flickr_conf_file;

my $flickr_conf = Config::Tiny->read( $flickr_conf_file );
plan skip_all => "Config::Tiny couldn't read conf file $flickr_conf_file "
                 . "defined in MAPSITE_FLICKR_CONF environment variable"
  unless $flickr_conf;

my $flickr_key    = $flickr_conf->{_}->{flickr_key}    || "";
my $flickr_secret = $flickr_conf->{_}->{flickr_secret} || "";

plan skip_all => "conf file $flickr_conf_file (defined in MAPSITE_FLICKR_CONF "
               . "environment variable) is lacking flickr_key or flickr_secret"
  unless $flickr_key && $flickr_secret;

# This is where we check if the Flickr key/secret are valid.
my $flickr_api = Flickr::API2->new({ key    => $flickr_key,
                                      secret => $flickr_secret });
eval {
  $flickr_api->execute_method( "flickr.photos.licenses.getInfo" );
};

if ( $@ ) {
  plan skip_all => "Either the Flickr key and secret (signature) in conf file "
      . "$flickr_conf_file (defined in MAPSITE_FLICKR_CONF environment "
      . "variable) aren't both valid, or there's a problem with the Flickr "
      . "API endpoint.  Error is: $@";
}

plan tests => 2;

# Make sure we have a cache directory, and clear out any old cached data.
make_path( "t/cache/" );
remove_tree( "t/cache/502/" );

my %data = MapSite->parse_datafile(
                                    file          => "t/data/502.yaml",
                                    check_flickr  => 1,
                                    flickr_key    => $flickr_key,
                                    flickr_secret => $flickr_secret,
                                    cache_dir     => "t/cache/502/",
                                 );

my $entity = $data{entities}[0];
ok( $entity->photo_copyright, "copyright owner of photo identified" );
ok( $entity->photo_license, "license of photo identified" );


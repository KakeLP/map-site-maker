package BookSite;
use strict;

use BookSite::Shop;
#use CGI;
use YAML::XS qw( LoadFile );

our $errstr;

=head1 NAME

BookSite - Makes the London Bookshop Map site.

=head1 DESCRIPTION

A set of tools for turning YAML into a website.

=head1 METHODS

=over

=item B<parse_yaml>

  # If you want to check Flickr for photo URLs/heights/widths, you must
  # supply both key and secret.  If one or both is missing then check_flickr
  # will be set to 0.

  my %data = BookSite->parse_yaml(
                                   file          => "datafile.yaml",
                                   check_flickr  => 1, # or 0
                                   flickr_key    => "mykey",
                                   flickr_secret => "mysecret",
                                 );

Returns a hash:

=over

=item shops - ref to an array of BookSite::Shop objects;

=item min_lat, max_lat, min_long, max_long - scalars

=back

=cut

sub parse_yaml {
  my ( $class, %args )  = @_;

  my $filename = $args{file} || die "No datafile supplied";
  my $check_flickr = $args{check_flickr} || 0;
  my $flickr_key = $args{flickr_key};
  my $flickr_secret = $args{flickr_secret};
  if ( !$flickr_key || !$flickr_secret ) {
    $check_flickr = 0;
  }

  my @data = LoadFile( $filename );

  @data = sort { $a->{name} cmp $b->{name} } @data;

  my @shops;
  my ( $min_lat, $max_lat, $min_long, $max_long );

  my ( $flickr_api, %licenses );
  if ( $check_flickr ) {
    $flickr_api = Flickr::API2->new({ key    => $flickr_key,
                                      secret => $flickr_secret });
    my $flickr_info = $flickr_api->execute_method(
                                          "flickr.photos.licenses.getInfo" );
    my @ids = @{ $flickr_info->{licenses}{license} };
    %licenses = map { $_->{id} => $_->{url} } @ids;
  }

  foreach my $datum ( @data ) {
    my $open = $datum->{open};
    if ( !$open || ( $open ne "yes" && $open ne "no" ) ) {
      $datum->{open} = "unknown";
    }

    if ( $check_flickr && $datum->{photo} ) {
      my $photo_url = $datum->{photo};

      my ( $user_id, $photo_id ) =
                          $photo_url =~ m{flickr.com/photos/([^/]+)/(\d+)};
      my $flickr_info = $flickr_api->execute_method(
                        "flickr.photos.getSizes", { photo_id => $photo_id } );
      my @photos = @{ $flickr_info->{sizes}{size} };

      $flickr_info = $flickr_api->execute_method(
                     "flickr.photos.getInfo", { photo_id => $photo_id } );
      my $photo_copyright = $flickr_info->{photo}{owner}{realname};
      $datum->{photo_copyright} = $photo_copyright;
      my $license_id = $flickr_info->{photo}{license};
      $datum->{photo_license} = $licenses{$license_id};

      foreach my $photo ( @photos ) {
        if ( $photo->{label} eq "Medium" ) {
          $datum->{photo_url} = $photo->{source};
          $datum->{photo_width} = $photo->{width};
          $datum->{photo_height} = $photo->{height};
        }
      }
    }

    my $shop = BookSite::Shop->new( %$datum );
    push @shops, $shop;

    if ( $shop->not_on_map ) {
      next;
    }

    my ( $lat, $long ) = $shop->lat_and_long;

    if ( !defined $min_lat ) {
      $min_lat = $max_lat = $lat;
    } elsif ( $lat < $min_lat ) {
      $min_lat = $lat;
    } elsif ( $lat > $max_lat ) {
      $max_lat = $lat;
    }
    if ( !defined $min_long ) {
      $min_long = $max_long = $long;
    } elsif ( $long < $min_long ) {
      $min_long = $long;
    } elsif ( $long > $max_long ) {
      $max_long = $long;
    }
  }

  return (
           shops => \@shops,
           min_lat => $min_lat,
           max_lat => $max_lat,
           min_long => $min_long,
           max_long => $max_long,
         );
}

=back

=cut

1;

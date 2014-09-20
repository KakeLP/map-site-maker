package MapSite;
use strict;

use MapSite::Entity;
use YAML::XS qw( LoadFile );

our $errstr;

=head1 NAME

MapSite - Makes websites like the London Bookshop Map site.

=head1 DESCRIPTION

A set of tools for turning YAML into a map-enabled website.

=head1 METHODS

=over

=item B<parse_yaml>

  # If you want to check Flickr for photo URLs/heights/widths, you must
  # supply both key and secret.  If one or both is missing then check_flickr
  # will be set to 0.

  my %data = MapSite->parse_yaml(
                                   file          => "datafile.yaml",
                                   check_flickr  => 1, # or 0
                                   flickr_key    => "mykey",
                                   flickr_secret => "mysecret",
                                 );

Returns a hash:

=over

=item entities - ref to an array of MapSite::Entity objects;

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

  # Load the YAML and throw away any blank data items (due to trailing
  # separators etc).
  my @data = LoadFile( $filename );
  @data = grep { defined $_ } @data;

  @data = sort { my $an = lc( $a->{name} );
                 my $bn = lc( $b->{name} );
                 foreach ( ( $an, $bn ) ) {
                   s/and//g;
                   s/the//g;
                   s/\s//g;
                 }
                 $an cmp $bn;
               } @data;

  my @entities;
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
    # Skip blanks.
    if ( !$datum->{name} ) {
      next;
    }
    my $open = $datum->{open} || "";
    if ( $open eq "yes" || $open eq "1" ) {
      $datum->{open} = 1;
    } else {
      $datum->{open} = 0;
    }

    if ( $check_flickr && $datum->{photo} ) {
      my $max_tries = 3;
      foreach my $try ( ( 1 .. $max_tries ) ) {
        eval {
          my $photo_url = $datum->{photo};

          my ( $user_id, $photo_id ) =
                            $photo_url =~ m{flickr.com/photos/([^/]+)/(\d+)};

          # Get the right size.
          my $size_data = $flickr_api->execute_method(
                        "flickr.photos.getSizes", { photo_id => $photo_id } );
          my @images = @{ $size_data->{sizes}{size} };

          foreach my $image ( @images ) {
            if ( $image->{label} eq "Medium" ) {
              $datum->{photo_url} = $image->{source};
              $datum->{photo_width} = $image->{width};
              $datum->{photo_height} = $image->{height};
            }
          }

          # Get the photographer and license.
          my $flickr_info = $flickr_api->execute_method(
                       "flickr.photos.getInfo", { photo_id => $photo_id } );
          my $photo_copyright = $flickr_info->{photo}{owner}{realname};
          if ( $photo_id eq "14863995906" ) {
            $photo_copyright = "Jim Linwood / Kake";
	  }
          $datum->{photo_copyright} = $photo_copyright;
          my $license_id = $flickr_info->{photo}{license};
          $datum->{photo_license} = $licenses{$license_id};

          # Get the creation date.
          my $exif_data = $flickr_api->execute_method(
                        "flickr.photos.getExif", { photo_id => $photo_id } );
          my @tags = @{ $exif_data->{photo}{exif} };
          foreach my $tag ( @tags ) {
            if ( $tag->{label} eq "Date and Time (Digitized)" ) {
              my ( $date, $time ) = split( /\s+/, $tag->{raw}{_content} );
              my ( $year, $month, $day ) = split( ":", $date );
              my @months = qw( January February March April May June July
                               August September October November December );
              $datum->{photo_date} = $months[$month - 1] . " " . $year;
              last;
            }
          }
        };
        last unless $@;
        if ( $try == $max_tries ) {
          die "Flickr call failed repeatedly for $datum->{name}: $@";
        }
      }
    }

    my $entity = MapSite::Entity->new( %$datum );
    push @entities, $entity;

    if ( $entity->not_on_map ) {
      next;
    }

    my ( $lat, $long ) = $entity->lat_and_long;

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
           entities => \@entities,
           min_lat => $min_lat,
           max_lat => $max_lat,
           min_long => $min_long,
           max_long => $max_long,
         );
}

=back

=cut

1;
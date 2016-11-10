package MapSite;
use strict;

use File::Spec;
use MapSite::Entity;
use MapSite::Generate;

use base qw( Class::Accessor );
MapSite->mk_accessors( qw( conf_file ) );

our $errstr;

our $VERSION = "0.004";

=head1 NAME

MapSite - Makes websites like the London Bookshop Map site.

=head1 DESCRIPTION

A set of tools for turning CSV or YAML datafiles into a map-enabled website.

=head1 METHODS

=over

=item B<new>

  my $mapsite = MapSite->new( conf_file => "conf/mapsite.conf" );

=cut

sub new {
  my ( $class, %args ) = @_;
  my $self = \%args;
  bless $self, $class;
  return $self;
}

=item B<generate_site>

  my $mapsite = MapSite->new( conf_file => "conf/mapsite.conf" );
  $mapsite->generate_site
    or die "Error: " . $MapSite::errstr . "\n";

=cut

sub generate_site {
  my $self = shift;
  my $generator = MapSite::Generate->new( conf_file => $self->conf_file);
  my $ret = $generator->generate_site;
  $errstr = $MapSite::Generate::errstr unless $ret;
  return $ret;
}

=item B<parse_datafile>

  # If you want to check Flickr for photo URLs/heights/widths, you must
  # supply both key and secret.  If one or both is missing then check_flickr
  # will be set to 0.

  my %data = MapSite->parse_datafile(
                                      file          => "datafile.yaml",
                                      check_flickr  => 1, # or 0
                                      flickr_key    => "mykey",
                                      flickr_secret => "mysecret",
                                      cache_dir     => "cache",
                                    );

The type of datafile will be determined from the extension - .yaml/.yml
and .csv are currently supported.

Returns a hash:

=over

=item entities - ref to an array of MapSite::Entity objects;

=item min_lat, max_lat, min_long, max_long - scalars

=back

The C<cache_dir> is used for e.g. caching Flickr photo information (as YAML).

=cut

sub parse_datafile {
  my ( $class, %args )  = @_;

  my $filename = $args{file} || die "No datafile supplied";
  my $check_flickr = $args{check_flickr} || 0;
  my $flickr_key = $args{flickr_key};
  my $flickr_secret = $args{flickr_secret};
  if ( !$flickr_key || !$flickr_secret ) {
    $check_flickr = 0;
  }
  my $cache_dir = $args{cache_dir} || "";

  my @data;
  if ( $filename =~ /\.ya?ml$/ ) {
    @data = $class->load_yaml( $filename );
  } elsif ( $filename =~ /\.csv$/ ) {
    @data = $class->load_csv( $filename );
  } else {
    die "Unknown file type: $filename";
  }

  # Throw away any blank data items (due to trailing separators etc).
  @data = grep { defined $_ } @data;

  # Sort by name, ignoring case, whitespace, and articles.
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

  # If we're checking Flickr for photo info, get the licences info and
  # load in any data we already have cached.
  my ( $flickr_api, %licenses, $flickr_file, %flickr_cache );
  if ( $check_flickr ) {
    $flickr_api = Flickr::API2->new({ key    => $flickr_key,
                                      secret => $flickr_secret });
    my $flickr_info = $flickr_api->execute_method(
                                          "flickr.photos.licenses.getInfo" );
    my @ids = @{ $flickr_info->{licenses}{license} };
    %licenses = map { $_->{id} => $_->{url} } @ids;

    die "cache_dir not set in call to parse_datafile" unless $cache_dir;
    unless ( -e $cache_dir || mkdir $cache_dir ) {
      die "Can't create cache directory $cache_dir: $!";
    }

    $flickr_file = File::Spec->catfile( $cache_dir, "flickr_data.yaml" );
    if ( -e $flickr_file ) {
      %flickr_cache = YAML::XS::LoadFile( $flickr_file );
    }
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
      my @data_needed = qw( photo_url photo_width photo_height
                            photo_copyright photo_license photo_date );

      my $photo_url = $datum->{photo};
      my ( $user_id, $photo_id ) =
                            $photo_url =~ m{flickr.com/photos/([^/]+)/(\d+)};

      # If we have cached data for this photo ID, just use that.
      my $cached_data = $flickr_cache{$photo_id};
      my $got_data = 0;
      if ( $cached_data ) {
        foreach my $key ( @data_needed ) {
          if ( $cached_data->{$key} ) {
            $datum->{$key} = $cached_data->{$key};
            $got_data++;
          }
        }
      }

      if ( $got_data == scalar @data_needed ) {
        # OK, got it all.
      } else {
        # We don't have all the cached data, so go and talk to Flickr.

        my $max_tries = 3;
        foreach my $try ( ( 1 .. $max_tries ) ) {
          eval {
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

            # Get the photographer and license.  Try to get their real name,
            # but fall back on their username.
            my $flickr_info = $flickr_api->execute_method(
                       "flickr.photos.getInfo", { photo_id => $photo_id } );
            my $photo_copyright = $flickr_info->{photo}{owner}{realname}
                                  || $flickr_info->{photo}{owner}{username};
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
              if ( $tag->{label} eq "Date and Time (Original)"
                   || $tag->{label} eq "Date and Time (Modified)" ) {
                my ( $date, $time ) = split( /\s+/, $tag->{raw}{_content} );
                my ( $year, $month, $day ) = split( ":", $date );
                my @months = qw( January February March April May June July
                                 August September October November December );
                $datum->{photo_date} = $months[$month - 1] . " " . $year;
                # If we've found the Original date, OK.  If we've only found
                # the Modified date, keep looking for the Original one.  Some
                # photos only have Modified, so that's the fallback.
                last if $tag->{label} eq "Date and Time (Original)";
              }
            }
          };
          last unless $@;
          if ( $try == $max_tries ) {
            die "Flickr call failed repeatedly for $datum->{name}: $@";
          }
        }

        # OK, we got the data from Flickr - now cache it.
        my $cached_data = {};
        $flickr_cache{$photo_id} = $cached_data;
        foreach my $key ( @data_needed ) {
          $cached_data->{$key} = $datum->{$key};
        }
        $flickr_cache{$photo_id} = $cached_data;
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

  # Write out any cached Flickr data.
  if ( $flickr_file ) {
    YAML::XS::DumpFile( $flickr_file, %flickr_cache );
  }

  return (
           entities => \@entities,
           min_lat => $min_lat,
           max_lat => $max_lat,
           min_long => $min_long,
           max_long => $max_long,
         );
}

sub load_yaml {
  my ( $class, $filename ) = @_;

  require YAML::XS;
  my @data = YAML::XS::LoadFile( $filename );

  return @data;
}

sub load_csv {
  my ( $class, $filename ) = @_;

  # Get the field names from the first line of the CSV.
  open my $fh, "<", $filename
    or die "Can't open $filename for reading: $!";
  my $fieldstr = <$fh>;
  close $fh or die "Can't close $filename: $!";

  my @fields = split /\s*,\s*/, $fieldstr;

  foreach ( @fields ) {
    # George stuff.
    s/ \(\?\)//g;

    # Other canonicalisation.
    $_ = lc( $_ );
    s/\s+$//;
    s/\s+/_/g;
    s/^latitude$/lat/;
    s/^longitude$/long/;
    s/^url$/website/;
    s/^summary$/description/;
    s/^wikipedia_url$/wikipedia/;
  }

  # Make a hash for easy access to see what fields we have.
  my %fieldhash = map { $_ => 1 } @fields;

  # Now read in the data.
  require Text::CSV::Simple;
  my $parser = Text::CSV::Simple->new({ binary => 1 });
  $parser->field_map( @fields );
  my @data = $parser->read_file( $filename );
  @data = @data[ 1 .. $#data ]; # strip the headings

  foreach my $datum ( @data ) {
    # Make sure everything has an ID.
    if ( !$datum->{id} ) {
      my $id = $datum->{name};
      $id =~ s/\s+/-/g;
      $id = lc( $id );
      $id =~ s/[^-a-z0-9]//g;
      $id =~ s/-+/-/g;
      $datum->{id} = $id;
    }

    # If we don't have an "open" field, add one so the templates don't think
    # everything has closed down.
    if ( !$fieldhash{open} ) {
      $datum->{open} = 1;
    }
  }

  return @data;
}

=back

=cut

1;

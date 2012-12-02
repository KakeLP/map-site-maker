package BookSite::Shop;
use strict;

use Flickr::API2;

use base qw( Class::Accessor );
BookSite::Shop->mk_accessors( qw(
    id name address lat long description photo photo_copyright photo_license
    new secondhand charity open checked
    website blog twitter rgl londonist reading_matters thebookguide
) );

=head1 NAME

BookSite::Shop - Model a single shop for the London bookshop map.

=head1 DESCRIPTION

Object modelling a single shop.

=head1 METHODS

=over

=item B<new>

  my $shop = BookSite::Shop->new(
    id => 12345,
    name => "A Book Shop",
    open => "yes",
    checked => "May 2012",
    address => "5 High Street, W1 1AA",
    lat => 51.00000,
    long => 0.10000,
    website => "http://example.com/bookshop/",
    rgl => "http://london.randomness.org.uk/wiki.cgi?A_Book_Shop",
    description => "This shop is an imaginary one, and it has now closed.",
    photo => "http://www.flickr.com/photos/kake_pugh/1234567890/",
    photo_url => "http://farm7.static.flickr.com/123456.jpg",
    photo_width => 500,
    photo_height => 320,
  );

=cut

sub new {
  my ( $class, %args ) = @_;
  my $self = \%args;
  bless $self, $class;
  return $self;
}

=item B<lat_and_long>

Returns an array containing the shop's latitude and longitude.  If one
of both of these data are missing, returns undef.

=cut

sub lat_and_long {
  my $self = shift;
  my $lat = $self->lat;
  my $long = $self->long;

  if ( !$lat || !$long ) {
    return undef;
  }
  return ( $lat, $long );
}

=item B<not_on_map>

Returns true if and only if either lat or long is missing.

=cut

sub not_on_map {
  my $self = shift;
  if ( $self->lat && $self->long ) {
    return 0;
  }
  return 1;
}

=item B<has_links>

  my $boolean = $shop->has_links;

Returns true if and only if the shop has at least one associated link, e.g.
RGL, Londonist, etc.

=cut

sub has_links {
  my $self = shift;
  foreach my $key ( qw( rgl londonist reading_matters thebookguide
                        other_links ) ) {
    if ( $self->{$key} ) {
      return 1;
    }
  }
  return 0;
}

=item B<Other accessors>

You can access any of the things you put in when you called new(), e.g.

  my $notes = $shop->description;

=back

=cut

sub TO_JSON {
  my $self = shift;
  return {
    id => $self->id,
    name => $self->name,
    lat => $self->lat,
    long => $self->long,
    not_on_map => $self->not_on_map,
    address => $self->address,
    open => $self->open,
  };
}

1;

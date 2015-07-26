package MapSite::Generate;

use strict;
use warnings;

use Config::Tiny;
use Cwd;
use Data::Dump qw( dump );
use File::Copy::Recursive qw( dircopy );
use File::Path qw( make_path remove_tree );
use File::Spec;
use POSIX qw( strftime );
use Template;

use base qw( Class::Accessor );
MapSite::Generate->mk_accessors( qw(
  base_url conf_file entity_type tt tt_base_vars
) );

our $errstr;

=head1 NAME

MapSite::Generate - Generates a MapSite site.

=head1 DESCRIPTION

Generates a MapSite site.

=head1 METHODS

=over

=item B<new>

  my $m = MapSite::generate->new( conf_file => "conf/mapsite.conf" );

=cut

sub new {
  my ( $class, %args ) = @_;
  my $self = \%args;
  bless $self, $class;
  return $self;
}

=item B<generate_site>

  my $m = MapSite::generate->new( conf_file => "conf/mapsite.conf" );
  $m->generate_site;

Generates the site into the C<_site> directory.  If something goes
wrong, the method sets C<$MapSite::Generate::errstr> and returns
false.

Returns true if all is well.

=cut

sub generate_site {
  my $self = shift;

  # Read the config files.
  my $conf_file = $self->conf_file
    or return $self->_return_error( "No conf_file supplied" );
  my $conf = Config::Tiny->read( $conf_file )
    or return $self->_return_error( "Can't read config file $conf_file: "
                              . "$Config::Tiny::errstr" );
  my $base_url = $conf->{_}->{base_url}
    or return $self->_return_error( "base_url not specified in $conf_file.\n" );
  $self->base_url( $base_url );

  # There may not be a Flickr conf - that's OK, we'll check whether
  # $flickr_conf is true later.
  my $flickr_conf = Config::Tiny->read( "conf/flickr_secrets.conf" );

  # Make sure we actually have a datafile, and that we can read it.
  my $datafile = $conf->{_}->{datafile}
    or return $self->_return_error( "Datafile not specified in $conf_file." );
  return $self->_return_error( "Datafile $datafile doesn't exist or is unreadable" )
    unless -r $datafile;

  # Make sure we know what type of thing we're modelling.
  my $entity_type = $conf->{_}->{entity_type}
    or return $self->_return_error( "Entity type not specified in $conf_file." );
  $self->entity_type( $entity_type );

  # Clear out and recreate the directory that the site will be generated into.
  my $err;
  remove_tree( "site", { error => $err } );
  if ( $err ) {
    for my $diag ( @$err ) {
      my ( $file, $message ) = %$diag;
        if ( $file ) {
          return $self->_return_error( "Problem unlinking $file: $message." );
        } else {
          $self->return_error( "General error: $message." );
        }
    }
  }
  make_path( "site" );
  make_path( "site/$entity_type" );
  make_path( "site/data" );
  make_path( "site/js" );

  # Copy over the static stuff, if there is any.
  if ( -d "static" ) {
    dircopy( "static", "site" )
      or return $self->_return_error( $! );
  }

  # Set up template stuff.
  my $tt_config = {
    INCLUDE_PATH => "custom_templates:templates",
    OUTPUT_PATH => "site/",
  };
  $self->tt( Template->new( $tt_config ) ) or croak Template->error;
  $self->tt_base_vars( {
    base_url => $base_url,
    entity_type => $entity_type,
    site_description => $conf->{_}->{site_description} || "A website with a lovely map.",
    site_name => $conf->{_}->{site_name} || "A MapSite website that hasn't configured its site_name",
  } );

  # Set up Flickr stuff.
  my $flickr_key = "";
  my $flickr_secret = "";
  if ( $flickr_conf ) {
    $flickr_key    = $flickr_conf->{_}->{flickr_key}    || "";
    $flickr_secret = $flickr_conf->{_}->{flickr_secret} || "";
  }

  # Parse the datafile.
  my %data = MapSite->parse_datafile(
    file          => $datafile,
    check_flickr  => 1,
    flickr_key    => $flickr_key,
    flickr_secret => $flickr_secret,
    cache_dir     => File::Spec->catfile( getcwd, "cache" ),
  );
  my @entities = @{ $data{entities} };

  my ( $min_lat, $max_lat, $min_long, $max_long )
    = @data{ qw( min_lat max_lat min_long max_long ) };

  # Generate the pages that need generating.
  my $map_file = "map.html";
  my $map_url = $base_url . $map_file;
  my $index_file = "list.html";
  my $index_url = $base_url . $index_file;
  my $kml_file = $conf->{_}->{kml_filename} || "$entity_type.kml";

  foreach my $entity ( @entities ) {
    # At a minimum we need an ID.
    return $self->_return_error( "Missing ID for entity:\n" . dump( $entity ) )
      unless $entity->{id};
    $self->write_entity_page( entity => $entity, map_url => $map_url,
                               index_url => $index_url );
  }

  $self->write_map_page( entities => \@entities, map_file => $map_file,
    index_url => $index_url,
    min_lat => $min_lat, max_lat => $max_lat,
    min_long => $min_long, max_long => $max_long );

  $self->write_index_page( index_file => $index_file, entities => \@entities,
                            map_url => $map_url );

  $self->write_about_page( about_file => "about.html" );
  $self->write_links_page( links_file => "links.html" );

  $self->write_kml_file( entities => \@entities, kml_file => $kml_file );

  # Copy over the assets (CSS, JS).  Some of these are generated.
  if ( -d "assets" ) {
    dircopy( "assets", "site" )
      or return $self->_return_error( $! );
  }
  my $tt_vars = $self->tt_base_vars;
  my $template = "map_js.tt";
  open( my $output_fh, ">", "site/js/map.js" )
    or return $self->_return_error( $! );
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
  close $output_fh;

  # If we get this far then hopefully we've succeeded.
  print "OK, done (generated website is in site/).\n";
  return 1;
}

sub write_entity_page {
  my ( $self, %args ) = @_;
  my $tt_vars = { %args, %{ $self->tt_base_vars } };
  my $template = "entity_page.tt";
  my $entity_type = $self->entity_type;

  open( my $output_fh, ">", "site/$entity_type/" . $args{entity}{id}
          . ".html" )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)"; # Avoid "Wide character in print".
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub get_time {
  # Some strftimes don't have %P.
  return strftime( "%l:%M", localtime )
           . lc( strftime( "%p", localtime ) )
           . strftime( " on %A %e %B %Y", localtime );
}

sub write_map_page {
  my ($self, %args ) = @_;

  my $tt_vars = {
    %{ $self->tt_base_vars },
    %args,
    centre_lat => ( ( $args{max_lat} + $args{min_lat} ) / 2 ),
    centre_long => ( ( $args{max_long} + $args{min_long} ) / 2 ),
    updated => $self->get_time(),
  };

  my $template = "map.tt";
  open( my $output_fh, ">", "site/" . $args{map_file} )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)";
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub write_index_page {
  my ($self, %args ) = @_;

  my $tt_vars = {
    %{ $self->tt_base_vars },
    %args,
    updated => $self->get_time(),
  };

  my $template = "list.tt";
  open( my $output_fh, ">", "site/" . $args{index_file} )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)";
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub write_about_page {
  my ( $self, %args ) = @_;

  my $tt_vars = {
    %{ $self->tt_base_vars },
    %args,
  };

  my $template = "about.tt";
  open( my $output_fh, ">", "site/" . $args{about_file} )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)";
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub write_links_page {
  my ( $self, %args ) = @_;

  my $tt_vars = {
    %{ $self->tt_base_vars },
    %args,
  };

  my $template = "links.tt";
  open( my $output_fh, ">", "site/" . $args{links_file} )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)";
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub write_kml_file {
  my ( $self, %args ) = @_;
  my @entities = @{$args{entities}};
  my $entity_type = $self->entity_type;
  my $base_url = $self->base_url;

  my @points;
  foreach my $entity ( @entities ) {
    if ( !$entity->lat || !$entity->long ) {
      next;
    }
    my %data = (
                 name => $entity->name,
                 long => $entity->long,
                 lat => $entity->lat,
                 address => $entity->address,
                 url => "$base_url$entity_type/" . $entity->id . ".html",
               );
    if ( $entity->open ne "yes" ) {
      $data{style} = "red";
    } else {
      $data{style} = "green";
    }
    push @points, \%data;
  }

  my $tt_vars = {
    %{ $self->tt_base_vars },
    points => \@points,
  };

  my $template = "kml.tt";
  open( my $output_fh, ">", "site/data/" . $args{kml_file} )
    or return $self->_return_error( $! );
  binmode $output_fh, ":encoding(UTF-8)";
  $self->tt->process( $template, $tt_vars, $output_fh )
    or return $self->_return_error( $self->tt->error );
}

sub _return_error {
  my ( $self, $error ) = @_;
  $errstr = $error;
  return 0;
}

=back

=cut

1;

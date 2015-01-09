package MapSite::Utils;
use strict;

use File::Slurp;
use MapSite::CSS;
use MapSite::Templates;

our $errstr;

=head1 NAME

MapSite::Utils - Utilities for the MapSite package.

=head1 DESCRIPTION

Utilities for the MapSite package.

=head1 METHODS

=over

=item B<initialise_site>

  MapSite::Utils->initialise_site;

Installs a basic skeleton in the current directory:

=over 8

=item * assets/main.css

=item * conf/mapsite.conf

=item * templates/<various_templates>.tt

=back

If one or more of the following directories exists and is non-empty,
the method sets C<$MapSite::Utils::errstr> and returns false:

=over 8

=item * assets

=item * assets/css

=item * conf

=item * templates

=back

If something goes wrong during installation, again the method sets
C<$MapSite::Utils::errstr> and returns false.

Returns true if all is well.

=cut

sub initialise_site {

  # Check there aren't any existing files in the way, and make directories.
  foreach my $dir ( qw( assets assets/css conf templates ) ) {
    if ( scalar glob "$dir/*" ) {
      $errstr = "$dir directory must initially be empty";
      return 0;
    }

    unless ( -e $dir || mkdir $dir ) {
      $errstr = "Can't mkdir '$dir': $!";
      return 0;
    }
  }

  # Write a basic conf file.
  my $fh;
  unless ( open $fh, ">", "conf/mapsite.conf" ) {
    $errstr = "Can't open conf/mapsite.conf for writing: $!";
    return 0;
  }

  print $fh <<EOF;
  base_url = http://localhost/
  datafile = mapsite.yaml
  entity_type = venues
  site_description = An unconfigured MapSite site.
  site_name = MapSite
EOF

  unless ( close $fh ) {
    $errstr = "Can't close conf/mapsite.conf: $!";
    return 0;
  }

  # Write out the templates.
  my @templates = MapSite::Templates->list_templates;

  foreach my $template ( @templates ) {
    my $content = MapSite::Templates->get_template( $template );
    unless ( $content ) {
      $errstr = "Couldn't get template $template";
      return 0;
    }

    unless ( open $fh, ">", "templates/$template" ) {
      $errstr = "Couldn't open templates/$template for writing: $!";
      return 0;
    }

    print $fh $content;

    unless ( close $fh ) {
      $errstr = "Couldn't close templates/$template: $!";
      return 0;
    }
  }

  # Write a basic stylesheet.
  my $css = MapSite::CSS->get_css( "basic" );
  unless ( $css ) {
    $errstr = "Couldn't get basic stylesheet";
    return 0;
  }

  unless ( open $fh, ">", "assets/css/main.css" ) {
    $errstr = "Can't open assets/css/main.css for writing: $!";
    return 0;
  }

  print $fh $css;
  unless ( close $fh ) {
    $errstr = "Can't close assets/css/main.css: $!";
    return 0;
  }

  return 1;
}

=back

=cut

1;

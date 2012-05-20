#!/usr/bin/perl -w

use strict;

use lib qw(
            /export/home/lb/lib/
            /export/home/lb/perl5/lib/perl5/
          );

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use Config::Tiny;
use File::Copy;
use POSIX qw( strftime );
use BookSite;
use Template;

my $HOME = "/export/home/lb";
my $base_dir = "$HOME/web/vhosts/londonbookshops.org/";
my $base_url = "http://londonbookshops.org/";

my $q = CGI->new;
my $cgi_url = $q->url();
$cgi_url =~ s|^(http://)www\.|$1|;

# Set up template stuff
my $tt_config = {
  INCLUDE_PATH => "$HOME/templates/",
  OUTPUT_PATH => $base_dir,
};
my $tt = Template->new( $tt_config ) or croak Template->error;
my %tt_base_vars = ( base_url => $base_url );

# If we aren't trying to upload, just print the form.
if ( $q->param( "action" ) && $q->param( "action" ) eq "regenerate" ) {
  regenerate_site();
  exit 0;
}
                  
if ( !$q->param( "Upload" ) ) {
  print_form_and_exit();
}

# Make sure we actually have a datafile.
my $tmpfile = $q->param( "datafile" );
if ( $q->param( "Upload" ) && !$tmpfile ) {
  print_form_and_exit( errmsg => "<p>Must supply a datafile.</p>" );
}

# OK, we have data to process.
my $tmpfile_name = $q->tmpFileName( $tmpfile );

my $succ_msg = do_upload( datafile      => $tmpfile_name,
                          datafile_name => $tmpfile );

my %tt_vars = (
                cgi_url => $cgi_url,
                base_url => $base_url,
                succ_msg => $succ_msg,
              );
print $q->header;
$tt->process( "upload_complete.tt", \%tt_vars ) || die $tt->error;

# subroutines

sub do_upload {
  my %args = @_;
  my $datafile_name = $args{datafile_name};
  my $datafile = $args{datafile};

  my $config = Config::Tiny->read( "$HOME/conf/lb.conf" )
                 or croak "Can't read config file: $Config::Tiny::errstr "
                        . "(please report this as a bug)";

  my $flickr_key    = $config->{_}->{flickr_key}    || "";
  my $flickr_secret = $config->{_}->{flickr_secret} || "";

  my %data = BookSite->parse_yaml(
    file          => $datafile,
    check_flickr  => 1,
    flickr_key    => $flickr_key,
    flickr_secret => $flickr_secret,
  );
  my @shops = @{ $data{shops} };

  my ( $min_lat, $max_lat, $min_long, $max_long )
    = @data{ qw( min_lat max_lat min_long max_long ) };

  my $map_file = "map.html";
  my $map_url = $base_url . $map_file;
  my $index_file = "list.html";
  my $index_url = $base_url . $index_file;
  my $kml_file = "data/bookshops.kml";
  my $kml_url = $base_url . $kml_file;

  foreach my $shop ( @shops ) {
    write_shop_page( shop => $shop, map_url => $map_url,
                     index_url => $index_url );
  }

  write_map_page( shops => \@shops, map_file => $map_file,
    index_url => $index_url,
    min_lat => $min_lat, max_lat => $max_lat,
    min_long => $min_long, max_long => $max_long );

  write_index_page( index_file => $index_file, shops => \@shops,
                    map_url => $map_url );

  write_kml_file( shops => \@shops, kml_file => $kml_file );

  # If we get this far then hopefully we've succeeded.
  my $succ_msg = "Data successfully uploaded. "
               . "<a href=\"$base_url$index_file\">Here is your index</a>, "
               . "<a href=\"$base_url$map_file\">here is your map</a>, and "
               . "<a href=\"$base_url$kml_file\">here is your KML</a>.";
  return $succ_msg;
}

sub write_shop_page {
  my %args = @_;
  my $tt_vars = { %args, %tt_base_vars };
  my $template = "shop_page.tt";

  open( my $output_fh, ">", "$base_dir/shops/" . $args{shop}{id} . ".html" )
      or die $!;
  $tt->process( $template, $tt_vars, $output_fh )
    || print_form_and_exit( errmsg => $tt->error );
}

sub get_time {
  # strftime on here doesn't have %P
  return strftime( "%l:%M", localtime )
         . lc( strftime( "%p", localtime ) )
         . strftime( " on %A %e %B %Y", localtime );
}

sub write_map_page {
  my %args = @_;

  my $tt_vars = {
    %tt_base_vars,
    %args,
    centre_lat => ( ( $args{max_lat} + $args{min_lat} ) / 2 ),
    centre_long => ( ( $args{max_long} + $args{min_long} ) / 2 ),
    updated => get_time(),
  };

  my $template = "map.tt";
  open( my $output_fh, ">", $base_dir . $args{map_file} ) or die $!;
  $tt->process( $template, $tt_vars, $output_fh )
    || print_form_and_exit( errmsg => $tt->error );
}

sub write_index_page {
  my %args = @_;

  my $tt_vars = {
    %tt_base_vars,
    %args,
    updated => get_time(),
  };

  my $template = "list.tt";
  open( my $output_fh, ">", $base_dir . $args{index_file} ) or die $!;
  $tt->process( $template, $tt_vars, $output_fh )
    || print_form_and_exit( errmsg => $tt->error );
}

sub write_kml_file {
  my %args = @_;
  my @shops = @{$args{shops}};

  my @points;
  foreach my $shop ( @shops ) {
    if ( !$shop->lat || !$shop->long ) {
      next;
    }
    my %data = (
                 name => $shop->name,
                 long => $shop->long,
                 lat => $shop->lat,
                 address => $shop->address,
                 url => $base_url . "shops/" . $shop->id . ".html",
               );
    if ( $shop->open ne "yes" ) {
      $data{style} = "red";
    } else {
      $data{style} = "green";
    }
    push @points, \%data;
  }

  my $tt_vars = {
    %tt_base_vars,
    points => \@points,
  };

  my $template = "kml.tt";
  open( my $output_fh, ">", $base_dir . $args{kml_file} ) or die $!;
  $tt->process( $template, $tt_vars, $output_fh )
    || print_form_and_exit( errmsg => $tt->error );
}

sub print_form_and_exit {
  my %args = @_;

  my %tt_vars = (
                  cgi_url => $cgi_url,
                  base_url => $base_url,
                  errmsg => $args{errmsg} || "",
                );
  print $q->header;
  $tt->process( "upload_form.tt", \%tt_vars ) || die $tt->error;
  exit 0;
}

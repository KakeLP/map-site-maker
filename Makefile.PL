use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "MapSite",
  VERSION_FROM => "lib/MapSite.pm",
  PREREQ_PM => {
    Config::Tiny => 0,
    File::Copy::Recursive => 0,
    File::Path => 0,
    File::Slurp => 0,
    Template => 0,
    # The below are only _sometimes_ required!
    # Flickr::API2
    # Text::CSV::Simple
    # YAML::XS
  }
);

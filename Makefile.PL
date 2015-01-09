use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "MapSite",
  VERSION_FROM => "lib/MapSite.pm",
  PREREQ_PM => {
    Config::Tiny => 0,
    Cwd => 0,
    File::Copy::Recursive => 0,
    File::Path => 0,
    File::Slurp => 0,
    File::Spec => 0,
    Flickr::API2 => 0,
    Template => 0,
    Text::CSV::Simple => 0,
    YAML::XS => 0,
  },
  EXE_FILES => [
    "bin/mapsite-init",
    "bin/mapsite-generate",
    "bin/mapsite-upgrade",
  ],
);

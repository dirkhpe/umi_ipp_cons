package IniUtil;

#####
# use
#####

use strict;
use warnings;
use Carp;
use File::Spec;
use File::Basename;
use Cwd;
use Config::IniFiles;
use Log::Log4perl qw(:easy);
use Data::Dumper;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK);

  $VERSION = '1.0';

  @ISA         = qw(Exporter);

  @EXPORT    = qw();

  @EXPORT_OK = qw(load_ini get_ini);
}

# ================================================================================
{

  my $cfg;
  my $ini_file;

  sub load_ini {
    confess "usage: load_ini([ options ])" unless @_ < 2;

    my $attr  = shift || {};

    # By default, look for the ini-file in the properties subfolder of the current directory
    my $ini_folder = File::Spec->catdir(cwd(), 'properties');
	# But read from ini_folder attribute if set
    $ini_folder = $attr->{ini_folder} if (exists $attr->{ini_folder});
	
	# By default, use the calling script name as basis for ini filename
	my ($basename, undef) = split /\./, basename($0);
	# But read from project attribute if set
	$basename = $attr->{project} if (exists $attr->{project});

	# Get ini filename and directory
	my $inifilename = $basename . ".ini";
    my $current_ini_file = File::Spec->catfile($ini_folder, $inifilename);

    # Never read more than one ini-file, to avoid confusion about what file is actually used.
    if (defined $ini_file) {
      # Warn, if the ini file location changes
      # Possible causes :
      # - use of a module that calls "get_ini" BEFORE the main script calls "load_ini".
      # - multiple calls to load_ini with different parameters
      unless ($ini_file eq $current_ini_file) {
        WARN("Multiple ini-file locations passed ($ini_file, $current_ini_file). This can cause confusion. We stick with `$ini_file'");
      }

      # but re-read the same file is allowed
      if (defined $cfg) {
        DEBUG("Re-reading ini file ...");
        my $rv = $cfg->ReadConfig;

        unless (defined $rv) {
          ERROR("Failed to re-read the ini file `$ini_file'");
          $cfg = undef;
          return;
        }

        return $cfg;
      }
    }
    else {
      $ini_file = $current_ini_file;
    }

    unless (-f $ini_file) {
      ERROR("ini-file `$ini_file' does not exists !");
      return;
    }

    DEBUG("Reading ini file `$ini_file' ...");
    $cfg = new Config::IniFiles( -file => $ini_file );

    unless (defined $cfg) {
      ERROR("Failed to parse ini-file `$ini_file' !");
      return;
    }

    return $cfg;
  }

  sub get_ini {

    return $cfg if (defined $cfg);

    # for main scripts that don't load the ini-file, we load the ini-file now.
    # The possibility to switch to an ini-file in a different loaction is lost, but thats ok because
    # the main script has no $opt_ini parameter in the first place.

    return load_ini();
  }

}

# ================================================================================

1;

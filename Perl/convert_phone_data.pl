=head1 NAME

convert_phone_data - Read Phone Data from text files, insert into msaccess tables.

=head1 VERSION HISTORY

version 1.0 12 June 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This file will read the phone extract files, containing more that 1000 records per line. The script will extract the required fields and populate the phone table in the database.

=head1 SYNOPSIS

 convert_phone_data.pl

 convert_phone_data -h	Usage
 convert_phone_data -h 1  Usage and description of the options
 convert_phone_data -h 2  All documentation

=head1 OPTIONS

=over 4

No inline options are available. There is a properties\cmdb.ini file that contains script settings.

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $cfg, $dbh, %phone_hash, $max_values);

#####
# use
#####

use FindBin;
use lib "$FindBin::Bin/lib";

use warnings;			    # show warning messages
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use DBI();
use DbUtil qw(db_connect create_record);
use Text::CSV_XS;

use Log::Log4perl qw(get_logger);
use SimpleLog qw(setup_logging);
use IniUtil qw(load_ini get_ini);

# use Data::Dumper;

################
# Trace Warnings
################

# use Carp;
# $SIG{__WARN__} = sub { Carp::confess( @_ ) };

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;
	if (defined $dbh) {
		$dbh->disconnect;
	}
	$log->info("Exit application with return code $return_code.");
	exit $return_code;
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

######
# Main
######

# Handle input values
my %options;
getopts("h:", \%options) or pod2usage(-verbose => 0);
# my $arglength = scalar keys %options;  
# if ($arglength == 0) {			# If no options specified,
#	$options{"h"} = 0;			# display usage.
#}
#Print Usage
if (defined $options{"h"}) {
    if ($options{"h"} == 0) {
        pod2usage(-verbose => 0);
    } elsif ($options{"h"} == 1) {
        pod2usage(-verbose => 1);
    } else {
		pod2usage(-verbose => 2);
	}
}
# Get ini file configuration
my $ini = { project => "cmdb" };
$cfg = load_ini($ini);
# Start logging
setup_logging;
$log = get_logger();
$log->info("Start application");
# Show input parameters
if ($log->is_trace()) {
	while (my($key, $value) = each %options) {
		$log->trace("$key: $value");
	}
}
# End handle input values

my  $csv = Text::CSV_XS->new ({binary => 1,
		                       auto_diag => 1,
							   sep_char => ","});

# Make database connection for vo database
$dbh = db_connect("ci_consolidation") or exit_application(1);

# Delete tables in sequence
my @tables = qw (ipphones_int);
foreach my $table (@tables) {
	if ($dbh->do("delete from $table")) {
		$log->debug("Contents of table $table deleted");
	} else {
		$log->fatal("Failed to delete `$table'. Error: " . $dbh->errstr);
		exit_application(1);
	}
}

my @phone_files = $cfg->val("phone_extracts", "file");
my @fields = qw(Device_Name Description Device_Pool Location Device_Type Directory_Number_1 Line_Text_Label_1 User_ID_1);
foreach my $phone_file (@phone_files) {
    my $openres = open(my $phone, "$phone_file");
	if (defined $openres) {
		$log->info("Now working on file $phone_file");
	} else {
		$log->fatal("Could not open file $phone_file for reading, exiting...");
		exit_application(1);
	}
	# Read title line
	# my $line = <Phone>;
	# chomp $line;
	# my @labels = split /,/,$line;
	my $labels = $csv->getline($phone);
	my $nr_labels = @$labels;
	# Now read through the file
	while (my $values = $csv->getline($phone)) {
		# chomp $line;
		# my @values = split /,/,$line;
		# Check if number of elements in @labels and @values is equal.
		my $nr_values = @$values;
		if ($nr_labels < $nr_values) {
			$log->error("Number of labels ($nr_labels) less than number of values ($nr_values)!");
			$max_values = $nr_labels;
		} else {
			$max_values = $nr_values;
		}
		undef %phone_hash;
		for (my $cnt=0; $cnt < $max_values; $cnt++) {
			$phone_hash{$labels->[$cnt]} = $values->[$cnt];
		}
		my $Device_Name = $phone_hash{"Device Name"} || "";
		my $Description = $phone_hash{"Description"} || "";
		my $Device_Pool = $phone_hash{"Device Pool"} || "";
		my $Location    = $phone_hash{"Location"}    || "";
		my $Device_Type = $phone_hash{"Device Type"} || "";
		my $Directory_Number_1 = $phone_hash{"Directory Number 1"} || "";
		# Remove leading / from phone number
		if (length($Directory_Number_1) > 5) {
			$Directory_Number_1 = substr($Directory_Number_1, 1);
		}
		my $Line_Text_Label_1 = $phone_hash{"Line Text Label 1"} || "";
		my $User_ID_1 = $phone_hash{"User ID 1"} || "";
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
	    create_record($dbh, "ipphones_int", \@fields, \@vals);
	}
	close $phone;
}

exit_application(0);

=head1 To Do

=over 4

=item *

Nothing for now...

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>

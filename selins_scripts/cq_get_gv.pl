#! /usr/bin/perl

# ---------------------------------------------------------------------------- #
# README:
#
# This code snippet queries ClearQuest and gets database entry for the specified
# GV number(s). It also reports the locked status of a ClearCase application
# label.
#
# PREREQUISITE:
#
#       1. Perl 5.8.8 or latest.
#       2. GV list file gv_list.txt. One GV number per line is allowed.
#          Comments can be inserted as a new line begining with hash symbol (#).
#       3. Ensure write permission to the directory running this script. The
#          script generates a report file (report.txt) in this directory. 
#
# HOW TO USE:
#
#       1. Prepare the GV list file gv_list.txt.
#       2. Open command window and get this script directory using cd command.
#       3. Execute the following command:
#              <ClearQuest CQperl.exe path>/CQperl.exe cq_get_gv.pl <CQ User name>
#                                      <CQ Password> <ClearCase application label>
#              
#              Example:
#              "C:/Program Files/Rational/ClearQuest/CQperl.exe" cq_get_gv.pl
#                                              cquser cqpass U1A10A00_DELIV_2
#
#       4. The GVs will be queried and logged as report.txt in the same
#          directory.
#
# KNOWN ISSUES:
#       1. ClearQuest API generates query results based on GV number, and it
#          is sorted in ascending order. Hence the report generated will be
#          in ascending order. i.e. The report GV order may not coincide with
#          the order mentioned in gv_list.txt.
# ---------------------------------------------------------------------------- #

use strict;
use Cwd;

use CQPerlExt;

# ---------------------------------------------------------------------------- #
# USER SETTINGS:
    my $report_file = "report.txt";

# CLEARQUEST SESSION INFORMATION:

    # Name of the CQ database. Enter GV for "GV : Gillingham:CR Database".
    my $database_name  = 'GV';

    # Master data set name. Leave it empty.
    my $database_set   = '';

    # Query Field. Add here the required ClearQuest fields as array
    # elements.
    my @query_field = ("id", "Submitter", "Owner", "Application", "State");

    # Projects to search. Currently not supported.
    # my @find_in_prj    = ('Cam and Crank Simulator', 'Honda D-Pro');

    # Mention any one VOB directory for the cleartool command.
    # NOTE: Forward slashes (/) are recomended to specify directory tree as they
    # can be used as such in Linux/Unix.
    my $vob_dir = "M:/SSY_UCA31_PHASE_8/gill_vob";

# ---------------------------------------------------------------------------- #

# COMMAND-LINE ARGUMENTS
    my $cq_login_name  = $ARGV[0];
    my $cq_password    = $ARGV[1];
    my $label          = $ARGV[2];

# ---------------------------------------------------------------------------- #
# VARIABLES DECLARATION:
    my @gv_list;
    my $query_var;
# ---------------------------------------------------------------------------- #

# Get GV list
print "\nReading GV list...\n";
open (GV, "gv_list.txt") or die "Unable to open GV list file \"gv_list.txt\"\n";

while (<GV>)
{
	# Skip blank lines and commented lines
	next if (m/^\s+$/ or m/^#/);
	chomp;
	push @gv_list, "GV000".$_;
}
print "Completed reading GV list.\n";

# Create report file-handle
open (REPORT, ">$report_file") or die "Unable to create report file.";

# Create a new ClearQuest session.
print "\nCreating ClearQuest session for the current user...\n";

my $CQsession = CQPerlExt::CQSession_Build();
$CQsession->UserLogon($cq_login_name, $cq_password, $database_name, $database_set);

print "ClearQuest session created.\n";

# Build the required query fields (or columns)
print "\nQuery build in process...\n";

my $query_def = $CQsession->BuildQuery('CR');
foreach $query_var (@query_field) {

	$query_def->BuildField($query_var);

}

# Build Query Filter
my $query_filter_node = $query_def->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
$query_filter_node->BuildFilter('id', $CQPerlExt::CQ_COMP_OP_EQ, \@gv_list);

# Unsupported - Project Search
# $query_filter_node->BuildFilter('Project', $CQPerlExt::CQ_COMP_OP_EQ, \@find_in_prj);

# Execute the Query
my $result_set = $CQsession->BuildResultSet($query_def);
$result_set->Execute();

# Get number of columns
my $columns = $result_set->GetNumberOfColumns();

# Print the Labels
print "\nStarted generating report...\n";
print REPORT "\n---------------------------------------------------------------------------\n";

for (my $i = 1; $i <= $columns; $i++) {
    print REPORT "\t" unless ($i == 1);
    my $value = $result_set->GetColumnLabel($i);
    print REPORT $value;
}

print REPORT "\n---------------------------------------------------------------------------\n";

# Print the GVs
while ($result_set->MoveNext() == $CQPerlExt::CQ_SUCCESS) {

    for (my $i = 1; $i <= $columns; $i++) {
        print REPORT "\t" unless ($i == 1);
        my $value = $result_set->GetColumnValue($i);
        # $value =~ s/\t/ /g;
        print REPORT $value;
    }

    print REPORT "\n";
}

# Close all open file handles.
close GV;
close REPORT;

print "Report generation completed.\n";

# ---------------------------------------------------------------------------- #
# CLEARCASE INTERFACE:
# ---------------------------------------------------------------------------- #

# Get current working directory
my $curr_dir = cwd();

# Change directory to VOB directory
chdir $vob_dir;

print "\nExecuting Cleartool command...\n";

# Execute ClearCase command
open (LABEL_READ, "cleartool describe lbtype:$label |");

my $lock_found  = 0;
my $label_found = 0;

# Check for LABEL locked.
while (my $line = <LABEL_READ>)
{
	if ($line =~ m/label type/)
	{
		$label_found = 1;
		chomp $line;

		my @fields = split (/\s/, $line);

		if ($fields[3] eq "(locked)")
		{
                        $lock_found = 1;
			last;
		}
		last;
	}
}

# Print result.
print "Label found but it is not locked.\n" if ($label_found == 1 and $lock_found == 0);
print "Label found and is locked.\n" if ($label_found == 1 and $lock_found == 1);
print "Error: No label found!!! Check the label name and VOB path.\n" if ($label_found == 0);

# Close file handle.
close LABEL_READ;

# Change back to the working directory
chdir $curr_dir;

__END__

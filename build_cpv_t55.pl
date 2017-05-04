#!/usr/bin/perl
########################################################################
#                    Delphi Diesel Systems
#*
#*                   This document is the property of
#*                   Delphi Diesel Systems
#*                   It must not be copied (in whole or in part)
#*                   or disclosed without prior written consent
#*                   of the company. Any copies by any method
#*                   must also include a copy of this legend.
#######################################################################
# 
# Description: Search header files for CPV values 
#              populate t55 CPV file
#
########################################################################
use strict;
use Win32::OLE;
use Getopt::Long;
use FileHandle;
use File::Copy;
use File::Basename;
use Cwd;

# Flush buffers
$| = 1;

#
# local variables
#
my $debug_on            = 1;
my $current_dir         = cwd;
my $config              = "config.py";
my $outfile             = "t55_duplicates";
my @headerfilelist      = ();
my $headerfilelistsize	= 0;
my $count               = 0;
my $cpvcount            = 0;
my $headerdir           = "src/include/";
my @recordlist          = ();
my $recordlistsize	= 0;
my $logfile             = "cpv_builder.log";
my $errorflag           = 0;
my @singlewordlist      = ();
my $singlewordlistsize	= 0;
my @cpvstore		= ();
my $cpvstoresize	= 0;
my $t55_template	= "cpv_template.t55";
my $t55_out_file	= "cpv_generated.t55";
my $create_cpv_file     = 1; # set to true to create a cpv dump file
my $cpv_dump_name       = "cpv_listing";

#
# verify we are in coding directory
#
if ( $current_dir !~ /6_coding/g )
{
    print "Error: This program must be run from 6_coding\n";
    exit;
}

print "\nDelphi Diesel Systems Limited\n";
print "Ulility to set CPV values\n"; 



#
# open log file
#
open (LOGFILE, ">$logfile") or die "Failed to open $logfile";

if($debug_on)
{
	print("debug mode\n");
}




#
# get list of header file names from config file
#
print LOGFILE "INFO: Current directory: $current_dir\n";

open( CONFIG, $config ) or die "Can't open $config\n";
print LOGFILE "INFO: Scanning $config\n";
while (<CONFIG>)
{
    my($line) = $_;

    # skip commented lines
    next if ( /^\#/ );                                # Skip # comments
    
    if ($line =~ /HeaderFile\('([\w\/\.]+)'[\,\)]/)
    {
        # strip out file name
        $line =~ s/\HeaderFile//g;
        $line =~ s/\(//g;
        $line =~ s/\)//g;
        $line =~ s/\'//g;
	$line =~ m/(.*\/)(.*)$/;      # strip directories
	$line = $2;
	$line =~ m/^(.*)(\.).*$/;     # strip text following '.'
	$line = $1;
        $line = $line . '.h';         # restore '.h'

	# put in list
        $headerfilelist[$count] = $line;
        $count ++;
    }
}
close CONFIG;

print LOGFILE "INFO: Listed $count header file(s)\n";

# process each header file

print LOGFILE "INFO: Processing headers\n";
foreach my $filepath (@headerfilelist)
{
    process_file($headerdir . $filepath);
}


print "identified " . $cpvcount . " CPVs in code\n";
print LOGFILE "INFO: Identified " . $cpvcount . " CPVs\n";

# Set CPV values where they are other CPV values
# and repeat process
process_single_word_values();
process_single_word_values();
process_single_word_values();
report_single_word_unknowns();

# load cpv values into the template
load_template();

# see what was found
#dump_array(@cpvstore);

# create a cpv listing
if(1 == $create_cpv_file)
{
	create_cpv_dump();
}

# report errors
if($errorflag)
{
    print "found errors, look in $logfile\n";
}


# closedown
close(LOGFILE);



##############################################################################
#    SUBROUTINES
##############################################################################


###############################################################################
#
# step through each header file listing each record
#
###############################################################################
sub process_file()
{
    my($path) = shift;

    if (-e $path)
    {
	open(HEADER_FILE, $path) or die "Can't open $path\n";

    	# step through each line 

    	debug_print("Processing: $path\n");

   	my @dataline = ();

	# parser
    	while (<HEADER_FILE>)
    	{
		# look for CPVs
                next if /^(\s)*$/;				# Skip blank lines using ';'.
		next if /((?:\/\*(?:[^*]|(?:\*+[^*\/]))*\*+\/)|(?:\/\/.*))/;	# Skip */ and // comments.

	        @dataline = split( ";", $_ );			# split line using semicolons
		$dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading and trailing white space.

		# seperate #defines
		if( $dataline[0] =~ /^\#define/ )
		{
			# seperate CPVs
			if( $dataline[0] =~ /_CPV/ )
			{
				$cpvcount++;
				process_cpv($dataline[0]);
			}
		}
    	}
	close HEADER_FILE;

	# record size of the cpv store
	$cpvstoresize = @cpvstore;
    }
    else
    {
	print LOGFILE "ERROR: could not open $path\n";
	$errorflag++;
    }
}


###############################################################################
#
# process each cpv line
#
############################################################################### 
sub process_cpv()
{
	$_ =~ s/\#define//g;			# strip #define
	$_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading and trailing white space.
	$_ =~ m/^(\w+)/;			# get first word
	my $cpvname = $1;                       # put first word in cpvname
	$_ =~ s/^(\w+)//;			# delete first word
	$_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading white space
	my $value = $_;                         # put remainder in value
	get_cpv_value($cpvname, $value);
}


###############################################################################
#
# process the value parameter
#
###############################################################################
sub get_cpv_value()
{
	my $name  = $_[0];
	my $value = $_[1];

	$value = strip_casts($value);	           	# strip casts
	$value =~ s/\(/ /g;				# strip leading brackets
	$value =~ s/\)/ /g;				# strip trailing brackets
	$value =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading white space

	# count words in the string
      	my $noofwords = split(" ", $value); 
	
	# filter parameter types:
	
	$value =~ s/\(/ /g;				# strip leading brackets
	$value =~ s/\)/ /g;				# strip trailing brackets
	$value =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading white space

	if( $value =~ /^0x(?-i:[\da-f]{1,4})/ )
	{
		# 0x hex  with lowercase
		$value = hex2dec($value);
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("0x lower hex: $name = $value\n");
	}
	elsif( $value =~ /^0x(?-i:[\dA-F]{1,4})/ )
	{
		# 0x hex  with uppercase
		$value = hex2dec($value);
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("0x upper hex: $name = $value\n");
	}
	elsif( $value =~ /^0X(?-i:[\da-f]{1,4})/ )
	{
		# 0X hex with lowercase
		$value = hex2dec($value);
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("0X lower hex: $name = $value\n");
	}
	elsif( $value =~ /^0X(?-i:[\dA-F]{1,4})/ )
	{
		# 0X hex with uppercase
		$value = hex2dec($value);
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("0X upper hex: $name = $value\n");
	}
	elsif( $value =~ /^(TRUE|FALSE)/ )  
	{
		# Boolean
		# select first word to strip any comments
		$value =~ m/^(\w+)/;
		$value = $1;
		my @record = [$name, $value];
        	push @cpvstore, @record;	
 		debug_print("Boolean: $name = $value\n");
	}
	elsif( $value =~ /^(\\)/ )  
	{
		# continuation charecter
		print LOGFILE "ERROR: Unsupported multiline: $name = $value\n";
	}
	elsif( $value =~ /^(DEC0|BIN0)/ )  
	{
		# one
		$value= 1;
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("$name = one: $value\n");
	}
	elsif( $value =~ /^(BIN4)/ )  
	{
		# BIN4
		$value= 32;
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("$name = BIN4: $value\n");
	}
	elsif( $value =~ /^(U16_MAX)/ )  
	{
		# U16_MAX
		$value= 65535;
		my @record = [$name, $value];
        	push @cpvstore, @record;	
		debug_print("$name = U16_MAX: $value\n");
	}
	elsif( $value =~ /^(?:[A-z])/ )  
	{
		# leading alpha charecter
		debug_print("Leading alpha char in name:$name = $value\n");
		# seperate single words
		if($noofwords > 1)
		{
			# multi word
		}
		else
		{
			# single word
			my @record = [$name, $value];
			push @singlewordlist, @record;
			debug_print("Single word: $name = $value\n");
		}
	}
	elsif($noofwords > 1)  
	{
		# more than single string
		print LOGFILE "ERROR: Unsupported multiple expression: $name = $value\n";
		print("ERROR: Unsupported multiple expression: $name = $value\n");
	}
	elsif($noofwords eq " ")
	{
		# lost value
		print LOGFILE "ERROR: No value: $name = $value\n";
		print("ERROR: No value: $name = $value\n");
	}
	elsif($noofwords == 0)
	{
		# lost value
		print LOGFILE "ERROR: No value: $name = $value\n";
		print("ERROR: No value: $name = $value\n");
	}
	else
	{
		# assume pure decimal
		# strip any trailing alpha characters
		$value =~ s/[A-z]//g;
		debug_print("Pure decimal: $name = $value\n");
		my @record = [$name, $value];
        	push @cpvstore, @record;	
	}

}


###############################################################################
#
# convert the hex string to decimal
#
###############################################################################
sub hex2dec()
{
	# convert hex to decimal
	$_ =~ s/\(/ /g;				# strip leading brackets
	$_ =~ s/\)/ /g;				# strip trailing brackets
	$_ =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading white space
	$_ =~ s/0x//;				# strip the 0x prefix
	$_ =~ s/0X//;				# or strip the 0X prefix
	my $decval = hex($_);   		# convert dec to hex
	return $decval;
}


###############################################################################
# 
# remove unneeded cast prefixes
#
###############################################################################
sub strip_casts()
{
	$_ =~ s/\(U8\)//g;		# strip U8 casts
	$_ =~ s/\(U16\)//g;		# strip U16 casts
	$_ =~ s/\(U32\)//g;		# strip U32 casts
	$_ =~ s/\(S8\)//g;		# strip S8 casts
	$_ =~ s/\(S16\)//g;		# strip S16 casts
	$_ =~ s/\(S32\)//g;		# strip S32 casts
	return $_;
}


###############################################################################
# 
# process singlewordlist
# search through cpvstore looking for a cpv name to match a value in the 
# singlewordlist 
#
###############################################################################
sub process_single_word_values()
{
	$singlewordlistsize = @singlewordlist;
	print LOGFILE "INFO: Processing " . $singlewordlistsize . " single string values\n";

	for (my $i = 0; $i < $singlewordlistsize; $i++)
	{
		debug_print("Searching for single word value used by $singlewordlist[$i][0]\n");
		for (my $j=0; $j<$cpvstoresize; $j++)
		{
			debug_print("comparing $singlewordlist[$i][1] with  $cpvstore[$j][0]\n");
			if($singlewordlist[$i][1] eq $cpvstore[$j][0])
			{
				debug_print("matched $singlewordlist[$i][1] with $cpvstore[$j][0]\n");	# found cpv value
				my @record = [$singlewordlist[$i][0], $cpvstore[$j][1]];		# push into cpvstore
			        push @cpvstore, @record;	
				splice @singlewordlist, $i, 1;						# and remove from singlewordlist
			}
		}
	}	
	dump_array(@singlewordlist);
	debug_print("\n");

	# update sizes of the arrays
	$cpvstoresize       = @cpvstore;
	$singlewordlistsize = @singlewordlist;
}


###############################################################################
sub report_single_word_unknowns()
{
	print LOGFILE "ERROR: Following are unknown:\n";
	foreach my $row(@singlewordlist)
	{
   		foreach my $val (@$row)
		{
	      		print LOGFILE "$val\n";
 		}	
	}
}



###############################################################################
sub dump_array()
{
	foreach my $row(@_)
	{
   		foreach my $val(@$row)
		{
	      		print "$val ";
   		}
		print "\n";	
	}
}



###############################################################################
#
# load t55 template with requested CPV values
#
###############################################################################
sub load_template()
{
	my $count = 0;

	debug_print("loading t55 output file\n");

    	open(TEMPLATE_FILE, $t55_template) or die "Can't open $t55_template\n";
    	open(OUTPUT_FILE, ">$t55_out_file") or die "Can't open $t55_out_file\n";
	
	# parser
    	while (<TEMPLATE_FILE>)
    	{
		# loop through cpv names - where found add value if stored
	
	        my @dataline = split( ";", $_ );		# split line using semicolons
		$dataline[0] =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;	# strip leading and trailing white space.

		# search cpv store for name
		for (my $i=0; $i<$cpvstoresize; $i++)
		{
			debug_print("compare $dataline[0] with $cpvstore[$i][0]\n");
			if($dataline[0] eq $cpvstore[$i][0])
			{
				# found cpv value
				debug_print("matched $dataline[0] with $cpvstore[$i][0]\n");
				$dataline[12] = $cpvstore[$i][1];	# add cpv store value into value field
				print OUTPUT_FILE join(";", @dataline);	# load line into output file
				print LOGFILE "INFO: Added $cpvstore[$i][0] to $t55_out_file\n";
				$count++;
  				last;
			}		
			elsif($i == ($cpvstoresize-1))
			{
				print LOGFILE "ERROR: Failed to find a value for $dataline[0]\n";
			}
		}	
	}

	if(0 < $count)
	{
		print "set $count values in $t55_out_file\n";
		$errorflag = 1;
	}

	# tidy up
	close(OUTPUT_FILE);
	close(TEMPLATE_FILE);
}



###############################################################################
#
# create a cpv listing file
#
###############################################################################
sub create_cpv_dump()
{
	# open the output file
    	open(OUTPUT_FILE, ">$cpv_dump_name") or die "Can't open $cpv_dump_name\n";

	foreach my $row(@cpvstore)
	{
		foreach my $val(@$row)
		{
  			print OUTPUT_FILE "        $val ";
		}
		print OUTPUT_FILE "\n";	
	}

	close(OUTPUT_FILE);
}



###############################################################################
#
# print to screen when $debug_on is set
#
###############################################################################
sub debug_print()
{
	if($debug_on)
	{
   		foreach my $val(@_)
		{
      			print "$val ";
   		}	
	}
}



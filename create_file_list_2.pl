
##############################
# Run this in x_coding directory
##############################

my %configlist = ();


##############################
# Scan config.py
##############################

print "Scanning config.py\n";
open CONFIG, "config.py";

while (<CONFIG>)
{
	my($line) = $_;

#test only	
#print $line . "\n";


	if ($line =~ /(SourceFile|HeaderFile|ProjectFile|T55File)\('([\w\/\.]+)'[\,\)]/)
	{
		my $filepath = $2;

#test only	
#print $filepath . "\n";


		#remove path from filename

		$filepath =~ /^(.+)[\/\\](.+)/;
		my $filename =  $2;

		$configlist{$filename} = 1;

#test only	
#print $filename . "\n\n";

	}
#	SourceFile('src/blois_src/Appli/fqd/src/FQD_Lo_Main_Bkg_Dmnd.c', OWNER = 'blois', CC_TYPE = 'spec', CCFLAGS = ['INTROM','INTRAM'])
#	HeaderFile('src/blois_src/Hwi/src/hwi_pic.h', OWNER = 'luxembourg')
#	ProjectFile('src/blois_src/Appli/c_i/c_i_volcano/src/clean.bat', OWNER='gillingham',
#	T55File('src/blois_src/Appli/itd/src/ITD_Nom1_Dmnd.t55')


}

close CONFIG;


##############################
# Scan directory
##############################


print "Running cleartool ls\n";
my $command = "cleartool ls -recurse -visible | find /v \"\\out\\\" > tmp_file_list.txt";
system($command );

print "processing ls output\n";
open TMP, "tmp_file_list.txt";

##.\src\appli\rpc\tests@@\main\0                           Rule: UNA02B00 [-mkbranch task_gv23029]
##.\src\appli\rpc\src\.sconsign
##.\src\appli\rpc\src\rpc.c --> ../../../../../../blois_soft_vob/Software/Appli/rpc/src/rpc.c

open NEW, '>' . "new_file_list.txt";

print NEW "config.py\n";


while (<TMP>)
{
	my($line) = $_;
	my $filepath;

	if ($line =~ /(.+)@@.+/)
	{
		$filepath = $1;
	}
	elsif ($line =~ /(.+)-->(.+)/)
	{
		$filepath = $2;
	}
	else
	{
		$filepath = $line;
	}


	#remove path from filename

	$filepath =~ /^(.+)[\/\\](.+)/;
	my $filename =  $2;

	if (($filepath ne "") && ($filename ne ""))
	{

		if ($configlist{$filename} > 0)
		{
		$filepath =~ s/\//\\/g;

#		if ($filepath =~ /\.\\\/]+(\w+_vob.+)/)
		if ($filepath =~ /.+\\(\w+_vob.+)/)
			{
				print NEW "..\\..\\$1\n";
			}
			else
			{
				print NEW $filepath . "\n";
			}
		}
	}

}

close TMP;
close NEW;




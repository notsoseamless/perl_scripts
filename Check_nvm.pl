
use strict ;
use Win32;

#3.60 : add padding

sub MsgBoxYesNoFlag {4}
sub MsgBoxResult_No {7}
sub MsgBoxResult_Yes {6}

my $softname = 'Check Nvm';
my $version_soft = 'V3.60';
my $current_addr = 0x64;
my $outmessage = '';

my $nb_param = scalar @ARGV;

if (($nb_param < 1) || ($nb_param > 4))
{
	print "\n\n                                $softname"
		, "\n              $softname $version_soft, ", scalar localtime, "\n"
		, "\n\t syntax:\n"
		, "\n\t check_nvm.pl <out_file.csv> [-nvm_size]\n"
   		, "\n\t check_nvm.pl <file.map> <p_l_nvm_data.c> <out_file.csv> [-nvm_size]\n";
	# abort program and return an error
    exit 1;
}

print "$softname $version_soft\n";

my $MapFile = "";
my $SrcFile = "";
my $SrcHFile = "";
my $DstFile = "";
my $Nvm_Min_Size_Mgt = 0;

if ($nb_param == 1)
{
	$DstFile = $ARGV[0] ;
	$MapFile = '';
	Get_Map_File();
	$SrcFile = 'Z:\blois_soft_vob\Software\P_L\p_l_nvm\src\p_l_nvm_data.c' ;
}
elsif ($nb_param == 2)
{
	$DstFile = $ARGV[0] ;
	$MapFile = '';
	Get_Map_File();
	$SrcFile = 'Z:\blois_soft_vob\Software\P_L\p_l_nvm\src\p_l_nvm_data.c' ;
	if (uc($ARGV[1]) =~ /\-NVM_SIZE/)
	{
		$Nvm_Min_Size_Mgt = 1;
	}
}
elsif ($nb_param == 3)
{
	$MapFile = $ARGV[0] ;
	$SrcFile = $ARGV[1] ;
	$DstFile = $ARGV[2] ;
}
elsif ($nb_param == 4)
{
	$MapFile = $ARGV[0] ;
	$SrcFile = $ARGV[1] ;
	$DstFile = $ARGV[2] ;
	if (uc($ARGV[3]) =~ /\-NVM_SIZE/)
	{
		$Nvm_Min_Size_Mgt = 1;
	}
}

$SrcHFile = $SrcFile;
$SrcHFile =~ s/\.c$/\.h/;
print "Inputs data :\n";
print "Offset : ".$current_addr."\n";
print "Map    : ".GetCCAttr("Name",$MapFile).".\n";
print "Src .c : ".GetCCAttr("Name",$SrcFile).".\n";
print "Src .h : ".GetCCAttr("Name",$SrcHFile).".\n";
print "Dst    : $DstFile\n";

##############################################################
## Browse source file
##############################################################

my $struct_step;
my $current_nvm_zone;
my %nvm_zone = ();
my @nvm_list_order;

$struct_step = 0;

Get_Source_File_Info();

##############################################################
## Browse map file
##############################################################

my $zone_nb = 0;
my $zone_size = 0;
my $max_zone_size = 0;
my $buffer_size = 0;
my $max_zone_name = '';

my $date;
Get_Date();

open (DST_FILE, "> $DstFile") or die ("Unable to open $DstFile\n");

print DST_FILE "Zone #;Zone Name;Var Name;Var Recovery;Var Addr;Var Size;Padding;Fault;Valid Flag;Read Status;Write Status";
if ($Nvm_Min_Size_Mgt == 1)
{
	print DST_FILE ";Size APV";
}
print DST_FILE "\n";

my %map_var_list;
my %map_var_num;
my @map_var_name;
my %map_var_size;
my %temp_map_list;
my %temp_map_var_size;

my $i=0;
my $compiler = '';
my $section;
my $map_line;

open (MAP_FILE, "< $MapFile") or die("Unable to open $MapFile\n");
while (<MAP_FILE>)
{
	$map_line = $_;
	my $varname = '';
	if ($compiler eq "")
	{
		if ($map_line =~ /^\s*$/)
		{
			# do nothing
		}
		elsif ($map_line =~ /Wind River/)
		{
			$compiler = 'DIAB';
		}
		else
		{
			$compiler = 'GNU';
		}
	}
	elsif ($compiler eq 'DIAB')
	{
		chomp $map_line;
		if ($map_line =~ /^\s*([A-Za-z0-9_]+)\s+([0-9a-f]+)\s+([0-9a-f]+)\s*$/)
		{
			$varname = $1;
			$temp_map_list{uc($2)} = $varname;
			$temp_map_var_size{$varname} = hex($3);
		}
		elsif ($map_line =~ /^\s*(__[A-Za-z0-9_]+)\s+([0-9a-f]+)\s*$/)
		{
			$varname = $1;
			$temp_map_list{uc($2)} = $varname;
		}
	}
	elsif ($compiler eq 'GNU')
	{
		if ($map_line =~ /Linker script and memory map/)
		{
			$section = 'ADDRESS_PARSE';
		}
		if ($section eq "ADDRESS_PARSE")
		{
			chomp $map_line;
			if ($map_line =~ /^\s*([A-Za-z0-9_]+)\s*\:\s*0x([0-9a-f]+)\s*\:\s*0x([0-9a-f]+)\s*\:[A-Z_]+\s*$/)
			{
				$varname = $1;
				$temp_map_list{uc($2)} = $varname;
				$temp_map_var_size{$varname} = hex($3);
			}
			if ($map_line =~ /^\s+0x([0-9a-f]+)\s+([A-Za-z0-9_]+)\s*$/)
			{
				$varname = $2;
				if (!exists $temp_map_list{uc($1)})
				{
					$temp_map_list{uc($1)} = $varname;
				}
			}
		}
	}
}
close MAP_FILE;

foreach my $addr (sort keys %temp_map_list)
{
	my $name = $temp_map_list{$addr};
	$map_var_list{$name} = $addr;
	$map_var_num{$name} = $i;
	$map_var_name[$i] = $name;
	$map_var_size{$map_var_name[$i-1]} = $temp_map_var_size{$map_var_name[$i-1]};
	$i++;
}

foreach my $zone (@nvm_list_order) 
{
	# get var list

	my $is_data;
	my $nb_data;

	$is_data = 0;
	$nb_data = 0;
	my %block_var = ();
	
	if (defined $map_var_list{$nvm_zone{$zone}{'start_var'}})
	{
		if (defined $map_var_list{$nvm_zone{$zone}{'end_var'}})
		{
			my $j;
			
			for ($j=$map_var_num{$nvm_zone{$zone}{'start_var'}}; $j<= $map_var_num{$nvm_zone{$zone}{'end_var'}}; $j++)
			{
				$block_var{$nb_data}{'var_end_addr'} = $map_var_list{$map_var_name[$j]};
				$nb_data++;
				$block_var{$nb_data}{'var_start_addr'} = $map_var_list{$map_var_name[$j]};
				$block_var{$nb_data}{'var_name'} = $map_var_name[$j];
				$block_var{$nb_data}{'rec_name'} = "No Recovery";
				$block_var{$nb_data}{'rec_start_addr'} = 0;
				$block_var{$nb_data}{'rec_end_addr'} = 0;
			}
			$block_var{$nb_data}{'var_end_addr'} = $map_var_list{$map_var_name[$j]};
		}
		else
		{
			die ("$nvm_zone{$zone}{'end_var'} not found in map file $MapFile.\n");
		}
	}
	else
	{
		die ("$nvm_zone{$zone}{'start_var'} not found in map file $MapFile.\n");
	}

	#get rec list

	if ($nvm_zone{$zone}{'start_rec'} eq "Not Found")
	{
		# No recovery. Ignore zone.
	}
	else
	{
		my $cnt;
		$cnt = 0;
		
		if (defined $map_var_list{$nvm_zone{$zone}{'start_rec'}})
		{
			if (defined $map_var_list{$nvm_zone{$zone}{'end_var'}})
			{
				my $j;
				
				for ($j=$map_var_num{$nvm_zone{$zone}{'start_rec'}}; $j <= $map_var_num{$nvm_zone{$zone}{'start_rec'}} + $nb_data-1; $j++)
				{
					$block_var{$cnt}{'rec_end_addr'} = $map_var_list{$map_var_name[$j]};
					$cnt++;
					$block_var{$cnt}{'rec_start_addr'} = $map_var_list{$map_var_name[$j]};
					$block_var{$cnt}{'rec_name'} = $map_var_name[$j];
				}
				$block_var{$cnt}{'rec_name'} = "No Recovery";
			}
			else
			{
				die ("$nvm_zone{$zone}{'end_var'} not found in map file $MapFile.\n");
			}
		}
		else
		{
			die ("$nvm_zone{$zone}{'start_var'} not found in map file $MapFile.\n");
		}
		
	}
	
	#compare data
	
	for (my $cnt=1; $cnt<=$nb_data; $cnt++)
	{
		print DST_FILE "$zone_nb;";
		if ($zone =~ /P_L_NVM_([A-Z_0-9]+)_CONFIG_DATA/)
		{
			print DST_FILE "$1;";
		}
		else
		{
			print DST_FILE "$zone;";
		}
		print DST_FILE "$block_var{$cnt}{'var_name'};";
		if ($nvm_zone{$zone}{'start_rec'} ne "Not Found")
		{
			print DST_FILE "$block_var{$cnt}{'rec_name'};";
		}
		else
		{
			print DST_FILE "No Recovery;";
		}

		# get the sizes of the variable and its recovery
		my $size_var;
		my $size_rec;
		$size_var = $map_var_size{$block_var{$cnt}{'var_name'}};
		$size_rec = $map_var_size{$block_var{$cnt}{'rec_name'}};

		print DST_FILE sprintf("0x%04X;%d;",$current_addr,$temp_map_var_size{$block_var{$cnt}{'var_name'}});
		if ($cnt == $nb_data)
		{
			print DST_FILE "0;";
		}
		else
		{
			print DST_FILE sprintf("%d;",$size_var-$temp_map_var_size{$block_var{$cnt}{'var_name'}});
		}

		$current_addr += $size_var;
		$zone_size += $size_var;

		# compare the sizes of the variable and its recovery
		if (($size_rec != $size_var) && ($cnt < $nb_data-1) && ($nvm_zone{$zone}{'start_rec'} ne "Not Found"))
		{
			print "ERROR ----------------------------------------\n";
			print "$block_var{$cnt}{'var_name'} size $size_var\n";
			print "$block_var{$cnt}{'rec_name'} size $size_rec\n";
			print "----------------------------------------------\n";
			print DST_FILE "ERROR IN RECOVERY SIZE !!!!!";
			
			$outmessage .= "ERROR RECOVERY SIZE $block_var{$cnt}{'var_name'} size $size_var, $block_var{$cnt}{'rec_name'} size $size_rec\n";

		}

		my $rec_name;
		if (($block_var{$cnt}{'var_name'} =~ /^.{2,3}_(.+)_(nvv|NVV)/) && ($block_var{$cnt}{'rec_name'} ne "No Recovery"))
		{
			$rec_name = uc($1);
			if (($block_var{$cnt}{'rec_name'} eq ("P_L_".$rec_name."_APV")) ||
			    ($block_var{$cnt}{'rec_name'} eq ("P_L_".$rec_name."_CPV")) ||
			    ($block_var{$cnt}{'rec_name'} eq ("CONST_P_L_".$rec_name."_CPV")))
			{
				#do nothing
			}
			else
			{
				print "WARNING : Name : $block_var{$cnt}{'var_name'} <-> $block_var{$cnt}{'rec_name'}\n";
				$outmessage .= "WARNING : Name : $block_var{$cnt}{'var_name'} <-> $block_var{$cnt}{'rec_name'}\n";
			}
		}
		elsif (($block_var{$cnt}{'rec_name'} ne "No Recovery"))
		{
			if (($block_var{$cnt}{'rec_name'} eq ($block_var{$cnt}{'var_name'}."_rec")))
			{
				#do nothing
			}
			else
			{
				print "WARNING : Name : $block_var{$cnt}{'var_name'} <-> $block_var{$cnt}{'rec_name'}\n";
				$outmessage .= "WARNING : Name : $block_var{$cnt}{'var_name'} <-> $block_var{$cnt}{'rec_name'}\n";
			}
		}

		if ($nvm_zone{$zone}{'fault_apv'} =~ /dummy/) 
		{
			print DST_FILE "NONE;";
		}
		else
		{
			print DST_FILE "$nvm_zone{$zone}{'fault_apv'};";
		}
		if ($nvm_zone{$zone}{'valid_st'} =~ /dummy/)
		{
			print DST_FILE "NONE;";
		}
		else
		{
			print DST_FILE "$nvm_zone{$zone}{'valid_st'};";
		}
		if ($nvm_zone{$zone}{'read_st'} =~ /dummy/)
		{
			print DST_FILE "NONE;";
		}
		else
		{
			print DST_FILE "$nvm_zone{$zone}{'read_st'};";
		}
		if ($nvm_zone{$zone}{'write_st'} =~ /dummy/)
		{
			print DST_FILE "NONE;";
		}
		else
		{
			print DST_FILE "$nvm_zone{$zone}{'write_st'};";
		}
		if ($Nvm_Min_Size_Mgt == 1)
		{
			print DST_FILE "$nvm_zone{$zone}{'size_apv'};";
		}
		print DST_FILE "\n";
	}

	if ($max_zone_size < $zone_size)
	{
		$max_zone_size = $zone_size;
		$max_zone_name = $zone;
	}
	$zone_size = 0;
	$zone_nb++;

}



open (SRC_HFILE, "< $SrcHFile") or die("Unable to open $SrcHFile\n");
while (<SRC_HFILE>)
{
	if (/\#define\s+P_L_NVM_OBJ_CPY_BUFFER_SIZE\s+(\d+)/)
	{
		$buffer_size = $1;
	}
}
close SRC_HFILE;
if ($buffer_size <= $max_zone_size)
{
	print "ERROR : Size of buffer can\'t containt the size of $max_zone_name section ($buffer_size < $max_zone_size)\n";
	$outmessage .= "ERROR : Size of buffer can\'t containt the size of $max_zone_name section ($buffer_size < $max_zone_size)\n";
}


print DST_FILE "\nMax block size : $max_zone_size \[$max_zone_name\]\n";

print DST_FILE "Generated by $softname $version_soft from :\n";
print DST_FILE GetCCAttr("Name",$SrcFile);
print DST_FILE "\n";
print DST_FILE GetCCAttr("Name",$SrcHFile);
print DST_FILE "\n";
print DST_FILE GetCCAttr("Name",$MapFile);
print DST_FILE "\n";
print DST_FILE "on $date\n";

print DST_FILE "\n$outmessage";

close DST_FILE;

print "End of Check\n";

exit (0);


################################################################################################

sub Get_Date
{
	my $sec;
	my $min;
	my $heure;
	my $mjour;
	my $mois;
	my $annee;
	my $sjour;
	my $ajour;
	my $isdst;
	
	#get date and time
	($sec,$min,$heure,$mjour,$mois,$annee,$sjour,$ajour,$isdst) = localtime(time);
	
	$mois = $mois + 1;
	$annee = $annee +1900;
	
	if (scalar($mjour) <10) 
		{
		$mjour = "0" . $mjour;
		}
	if (scalar($mois) <10) 
		{
		$mois = "0" . $mois;
		}
	if (scalar($heure) <10) 
		{
		$heure = "0" . $heure;
		}
	if (scalar($min) <10) 
		{
		$min = "0" . $min;
		}
	
	$date = $mjour."/".$mois."/".$annee." ".$heure.":".$min; 
}
################################################################################################

sub Get_Source_File_Info
{
	open (SRC_FILE, "< $SrcFile") or die("Unable to open $SrcFile\n");
	while (<SRC_FILE>)
	{
		chomp;
		if ($struct_step == 1)
		{
			if (/&(P_L_NVM_[0-9_A-Za-z]+_CONFIG_DATA)/)
			{
				$current_nvm_zone = ($1);
				push @nvm_list_order, $current_nvm_zone;
			}
			elsif (/\}\s*;/)
			{
				$struct_step = 2;
			}
		}
		elsif ($struct_step == 2)
		{
			#wait end of file
		}
		elsif (/P_L_NVM_CONFIG_TYPE\s*\*\s*const\s+P_L_NVM_OBJ_CFG_PTR_LIST\s*\[\s*P_L_NVM_OBJ_NB_CPV\s*\]\s*=/)
		{
			$struct_step = 1;
		}
		
	}
	close SRC_FILE;
	
	$struct_step = 0;
	
	open (SRC_FILE, "< $SrcFile") or die("Unable to open $SrcFile\n");
	while (<SRC_FILE>)
	{
		chomp;
	
		if ($struct_step == 1)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'start_var'} = $1;
				$struct_step = 2;
			}
			elsif (/(__[0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'start_var'} = $1;
				$struct_step = 2;
			}
		}
		elsif ($struct_step == 2)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'end_var'} = $1;
			}
			elsif (/(__[0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'end_var'} = $1;
			}
			$struct_step = 3;
		}
		elsif ($struct_step == 3)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'start_rec'} = $1;
			}
			elsif (/(__[0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'start_rec'} = $1;
			}
			$struct_step = 4;
		}
		elsif ($struct_step == 4)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'valid_st'} = $1;
			}
			elsif (/(__[0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'valid_st'} = $1;
			}
			$struct_step = 5;
		}
		elsif ($struct_step == 5)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'read_st'} = $1;
			}
			$struct_step = 6;
		}
		elsif ($struct_step == 6)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'write_st'} = $1;
			}
			$struct_step = 7;
		}
		elsif ($struct_step == 7)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'fault_apv'} = $1;
			}
			if ($Nvm_Min_Size_Mgt != 1)
			{
				$struct_step = 0;
			}
			else
			{
				$struct_step = 8;		
			}
		}
		elsif ($struct_step == 8)
		{
			if (/&([0-9_A-Za-z]+)/)
			{
				$nvm_zone{$current_nvm_zone}{'size_apv'} = $1;
			}
			$struct_step = 0;
		}
		elsif (/P_L_NVM_CONFIG_TYPE\s+(P_L_NVM_[0-9_A-Z]+_CONFIG_DATA)/)
		{
		$current_nvm_zone = ($1);
		$nvm_zone{$current_nvm_zone}{'start_var'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'end_var'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'start_rec'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'valid_st'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'read_st'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'write_st'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'fault_apv'} = "Not Found";
		$nvm_zone{$current_nvm_zone}{'size_apv'} = "Not Found";
		$struct_step = 1;
		}
	}
	close SRC_FILE;
}

################################################################################################

sub Get_Map_File
{

	my $dpath ;
	my @dlist = ();
	my $fdate = 0;
	
	$dpath = 'Z:\blois_soft_vob\Software\_Software\out';
	
	opendir(DIR, "$dpath") || die "can't open dir $dpath : $!";
	@dlist = readdir(DIR);
	closedir DIR;
	foreach my $fname (@dlist)
	{
		if ($fname =~ /\.map$/)
		{
		my $write_secs;
		$write_secs = (stat("$dpath\\$fname"))[9];
			if ($write_secs > $fdate)
			{
				$fdate = $write_secs;
				$MapFile = "$dpath\\$fname";
			}
		}
	}
	
	my $response;
	if ($MapFile eq "")
	{
		$response = MsgBoxResult_No;
	}
	else
	{
			my $message .= "\nDo you want to check from $MapFile ?\n";
			$response = Win32::MsgBox($message ,MsgBoxYesNoFlag, "$softname $version_soft");
	}
	
	if ($response == MsgBoxResult_No)
	{
		$fdate = 0;
		$dpath = 'Z:\blois_soft_vob\Software\_Software\target_bin';
		
		opendir(DIR, "$dpath") || die "can't open dir $dpath : $!";
		@dlist = readdir(DIR);
		closedir DIR;
		foreach my $fname (@dlist)
		{
			if ($fname =~ /\.map$/)
			{
			my $write_secs;
			$write_secs = (stat("$dpath\\$fname"))[9];
				if ($write_secs > $fdate)
				{
					$fdate = $write_secs;
					$MapFile = "$dpath\\$fname";
				}
			}
		}
	}
	
	if ($MapFile eq "")
	{
		die("No Map File found.\n");
	}
}

################################################################################################

sub GetCCAttr
{
	my ($CcAttr, $path) = @_ ;	# Attribut + Path

	my $desc;

	# Get ClearCase attributes on file
	if ($CcAttr eq "Name")
	{
		$desc = `cleartool describe -s $path` ; 
		if ($desc eq "<name-unknown>")
		{
			$desc = $path." CHECKEDOUT";
		}
	}
	else
	{
		$desc = `cleartool describe -s -aattr \"$CcAttr\" $path` ; 
	}		
	
	$desc =~ s/\"//g  ;
	$desc =~ s/\n//g  ;

	return $desc ;	
}

__END__

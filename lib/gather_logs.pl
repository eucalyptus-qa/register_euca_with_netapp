#!/usr/bin/perl

use strict;

require './timed_run.pl';

use Cwd;

$ENV{'PWD'} = getcwd();

if( $ENV{'TEST_DIR'} eq "" ){
        my $cwd = getcwd();
        if( $cwd =~ /^(.+)\/lib/ ){
                $ENV{'TEST_DIR'} = $1;
        }else{
                print "ERROR !! Incorrect Current Working Directory ! \n";
                exit(1);
        };
};


# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @version_lst;
my @arch_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

#### read the input list

my $index = 0;

open( LIST, "< ../input/2b_tested.lst" ) or die $!;

my $line;
while( $line = <LIST> ){
	chomp($line);
	if( $line =~ /^([\d\.]+)\t(.+)\t(.+)\t(\d+)\t(.+)\t\[(.+)\]/ ){
                print "IP $1 [Distro $2, Version $3, Arch $4] will be built from $5 with Eucalyptus-$6\n";
		if( !( $2 eq "VMWARE" || $2 eq "WINDOWS" ) ){

	                push( @ip_lst, $1 );
	                push( @distro_lst, $2 );
	                push( @version_lst, $3 );
	                push( @arch_lst, $4 );
	                push( @source_lst, $5 );
	                push( @roll_lst, $6 );

			my $this_roll = $6;

			if( does_It_Have($this_roll, "CLC") ){
				$clc_index = $index;
				$clc_ip = $1;
			};

			if( does_It_Have($this_roll, "CC") ){
				$cc_index = $index;
				$cc_ip = $1;

				if( $this_roll =~ /CC(\d+)/ ){
					$cc_lst{"CC_$1"} = $cc_ip;
					if( $1 > $max_cc_num ){
						$max_cc_num = $1;
					};
				};			
			};

			if( does_It_Have($this_roll, "SC") ){
				$sc_index = $index;
				$sc_ip = $1;

				if( $this_roll =~ /SC(\d+)/ ){
	                                $sc_lst{"SC_$1"} = $sc_ip;
	                        };
			};

			if( does_It_Have($this_roll, "WS") ){
	                        $ws_index = $index;
	                        $ws_ip = $1;
	                };

			if( does_It_Have($this_roll, "NC") ){
				$nc_ip = $1;
				if( $this_roll =~ /NC(\d+)/ ){
					if( $nc_lst{"NC_$1"} eq	 "" ){
	                                	$nc_lst{"NC_$1"} = $nc_ip;
					}else{
						$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
					};
	                        };
	                };
			$index++;
		};
        };
};

close( LIST );

if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
        $ENV{'EUCALYPTUS'} = "";
};



my $log_dir = "../artifacts/logs/";

if( -e "$log_dir" ){
	system("rm -fr $log_dir");
};

system("mkdir -p $log_dir");

#Grabbing Cloud Log
system( "mkdir -p $log_dir" . $clc_ip . "_CLC" );

print "\nCopying $clc_ip :: $ENV{'EUCALYPTUS'}/var/log/eucalyptus/cloud-output.log to $log_dir/$clc_ip\n";


#timed_run("scp -o StrictHostKeyChecking=no root\@$clc_ip:$ENV{'EUCALYPTUS'}/var/log/eucalyptus/cloud-output.log " . $log_dir . $clc_ip . "_cloud-output.log", 30);
timed_run("scp -o StrictHostKeyChecking=no root\@$clc_ip:$ENV{'EUCALYPTUS'}/var/log/eucalyptus/cloud-* " . $log_dir . $clc_ip . "_CLC/" , 60);

check_timed_run("clod-output.log from $clc_ip");


for( my $i = 0; $i <= $max_cc_num; $i++){

	my $group = sprintf("%02d", $i);

	my $my_cc_ip = $cc_lst{"CC_$group"};

	#Grabbing CC Log
	system( "mkdir -p $log_dir" . $my_cc_ip . "_CC" . $group );

	print "\nCopying $my_cc_ip :: $ENV{'EUCALYPTUS'}/var/log/eucalyptus/cc.log Files\n";
	timed_run("scp -o StrictHostKeyChecking=no root\@$my_cc_ip:$ENV{'EUCALYPTUS'}/var/log/eucalyptus/cc* " . $log_dir . $my_cc_ip . "_CC" . $group . "/", 60);
	check_timed_run("cc.log from $cc_ip");
	
	my @nc_ips = split( / /, $nc_lst{"NC_$group"} );
	
	foreach my $my_nc_ip ( @nc_ips ){
		#Copying Node Log
		system( "mkdir -p $log_dir" . $my_nc_ip . "_NC" . $group );

                print "\nCopying $my_nc_ip :: $ENV{'EUCALYPTUS'}/var/log/eucalyptus/nc.log Files\n";
                timed_run("scp -o StrictHostKeyChecking=no root\@$my_nc_ip:$ENV{'EUCALYPTUS'}/var/log/eucalyptus/nc* " . $log_dir . $my_nc_ip . "_NC" . $group  . "/", 60);
		check_timed_run("nc.log from $my_nc_ip");
	};
};



############# subroutine ####################


sub check_timed_run{
	my $str = shift;

	my $rc = $? >> 8;

	if( $rc == 1 ){
		print "Failled to Download the Log File from $str\n";
		exit(1);
	};
	return 0;
};


1;


# <START_DESCRIPTION>
# NAME: _gather_logs
# LANGUAGE: perl
# USAGE: _gather_logs  
# REQUIREMENT : 2b_tested.lst file in your ./input directory of this test directory
#               set up passwordless ssh connection to all the machines in 2b_tested.lst; this can be accomplished by running _copy_rsa_keys script
# DESCRIPTION : This script gathers all the log files from the machines in 2b_test.lst file
# <END_DESCRIPTION>


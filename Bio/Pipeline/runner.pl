#!/usr/bin/perl
# Script for running an analysis on node or locally on a single machine
# 
# adapted from EnsEMBL::Pipeline runner.pl
#
# Copyright FuguI IMCB 
# 
# You may distribute this code under the same terms as perl itself
#
#


use Bio::Pipeline::SQL::DBAdaptor;
use Sys::Hostname;

use Bio::Pipeline::PipeConf qw  (DBHOST
                                 DBNAME
                                 DBUSER
                                 DBPASS
                                 NFSTMP_DIR
                                );
use Getopt::Long;


#parameters for Bio::Pipeline::SQL::DBAdaptor

my $host    = $DBHOST;
my $dbname  = $DBNAME;
my $dbuser  = $DBUSER;
my $pass    = undef;
my $port    = '3306';


GetOptions(
    'host=s'    => \$host,
    'port=n'    => \$port,
    'dbname=s'  => \$dbname,
    'dbuser=s'  => \$dbuser,
    'pass=s'    => \$pass,
    'check!'    => \$check,
    'action=s'  => \$action,
)
or die ("Couldn't get options");
my (@job_ids) = @ARGV;

if( defined $check ) {
  my $host = hostname();
  if ( ! -e $::NFSTMP_DIR ) {
    die "no nfs connection";
  }
  my $deadhostfile = $::NFSTMP_DIR."/deadhosts";
  open( FILE, $deadhostfile ) or exit 0;
  while( <FILE> ) {
    chomp;
    if( $host eq $_ ) {
      die "Cant use this host";
    }
  }

  # tests for DB existence - these probably shouldn't be hard-wired in ...
  if (defined (my $dir = $ENV{"BLASTDB"})) {
    -e "$dir/unigene.seq" or warn "Not found unigene";
    -e "$dir/sptr" or warn "Not found sptr";
  }
  exit 0;

}

my $db = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $host,
    -user   => $dbuser,
    -dbname => $dbname,
    -pass   => $pass,
    -port   => $port,
    -perlonlyfeatures  => 1,
    -perlonlysequences => 1
)
or die ("Failed to create Bio::Pipeline::SQL::DBAdaptor to db $dbname \n");

print STDERR "Connected to database\n";
print STDERR "Getting job adaptor\n";

my $job_adaptor = $db->get_JobAdaptor();

print STDERR "Fetching job " . $job_id . "\n";

foreach my $job_id (@job_ids){

#    my $job         = $job_adaptor->fetch_by_dbID($job_id);
    my $job = &create_new_job($job_id,$action);

    if( !defined $job) {
        print STDERR ( "Couldnt recreate job $job_id\n" );
    }

    print STDERR "Running job $job_id\n";
    print STDERR "Runnable is " . $job->analysis->runnable. "\n";

    eval {
        $job->run;
    };
    $pants = $@;

    if ($pants) {
        print STDERR "Job $job_id failed: [$pants]";
    }

    print STDERR "Finished job $job_id\n";
    print STDERR "Leaving runnabledb.pl\n";
}
$db->{'_db_handle'}->disconnect();

#recreating job in runner.pl. Here we need to differentiate the way we add the inputs
#for now logic only for WAITFORALL_AND_UPDATE, need to pass in a array ref of inputs
#from new_input table 

sub create_new_job{
    my ($job_id,$action) = @_;
    my $job = $job_adaptor->fetch_by_dbID($job_id);
    my @rules       = $job_adaptor->db->get_RuleAdaptor->fetch_all;
    if ($action eq 'WAITFORALL_AND_UPDATE'){
      my @inputs = $job->inputs;
      $job->flush_inputs();
      $job->add_input(\@inputs);
    }
    return $job;
}


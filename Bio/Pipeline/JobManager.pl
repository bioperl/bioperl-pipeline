# Script for managing a batch of jobs submitted to a job management system
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
# Last modified : 15.06.2001 by Simon Potter
#
# rewritten for bioperl-pipeline <jerm@fugu-sg.org>
#
# Copyright EMBL-EBI 2000
#
# You may distribute this code under the same terms as perl itself


use strict;
use Getopt::Long;

use Bio::Pipeline::SQL::RuleAdaptor;;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::StateInfoContainer;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::SQL::BaseAdaptor;

# defaults: command line options override pipeConf variables,
# which override anything set in the environment variables.

use Bio::Pipeline::PipeConf qw ( DBHOST 
                                 DBNAME
                                 DBUSER
                                 DBPASS
                                 QUEUE
                                 USENODES
                				 NFSTMP_DIR
                                 BATCHSIZE
                                 JOBNAME
                                 RETRY
				                 SLEEP
			        );

my $DBHOST    = $DBHOST;
my $DBNAME    = $DBNAME;
my $DBUSER    = $DBUSER;
my $DBPASS    = $DBPASS;
my $QUEUE     = $QUEUE;
my $NODES     = $USENODES;
my $workdir   = $NFSTMP_DIR;
my $FLUSHSIZE = $BATCHSIZE;
my $JOBNAME   = $JOBNAME;
my $RETRY     = $RETRY;
my $SLEEP     = $SLEEP;


$| = 1;

my $chunksize    = 500000;  # How many InputIds to fetch at one time
my $currentStart = 0;       # Running total of job ids
my $completeRead = 0;       # Have we got all the input ids yet?
my $local        = 0;       # Run failed jobs locally
my $analysis;               # Only run this analysis ids
my $submitted;
my $JOBNAME;                # Meaningful name displayed by bjobs
			    # aka "bsub -J <name>"
			    # maybe this should be compulsory, as
			    # the default jobname really isn't any use
my $idlist;
my ($done, $once);

GetOptions(
    'host=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'flushsize=i' => \$FLUSHSIZE,
    'local'       => \$local,
    'idlist=s'    => \$idlist,
    'queue=s'     => \$QUEUE,
    'jobname=s'   => \$JOBNAME,
    'usenodes=s'  => \$NODES,
    'once!'       => \$once,
    'retry=i'     => \$RETRY,
    'analysis=s'  => \$analysis
)
or die ("Couldn't get options");

my $db = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
);

my $ruleAdaptor = $db->get_RuleAdaptor;
my $jobAdaptor  = $db->get_JobAdaptor;
#my $sic         = $db->get_StateInfoContainer;


# scp
# $LSF_params - send certain (LSF) parameters to Job. This hash contains
# things LSF wants to know, i.e. queue name, nodelist, jobname (things that
# go on the bsub command line), plus the queue flushsize. This hash is
# passed to batch_runRemote which passes them on to flush_runs.
#
# The idea is that you could have more than one of these hashes to suit
# different types of jobs, with different LSF options. You would then define
# a queue 'resolver' function. This would take the Job object and return the
# queue type, based on variables in the Job/underlying Analysis object.
#
# For example, you could put slow (e.g., blastx) jobs in a different queue,
# or on certain nodes, or simply label them with a different jobname.

my $LSF_params = {};
$LSF_params->{'queue'}     = $QUEUE if defined $QUEUE;
$LSF_params->{'nodes'}     = $NODES if $NODES;
$LSF_params->{'flushsize'} = $FLUSHSIZE if defined $FLUSHSIZE;
$LSF_params->{'jobname'}   = $JOBNAME if defined $JOBNAME;

# Fetch all the analysis rules.  These contain details of all the
# analyses we want to run and the dependences between them. e.g. the
# fact that we only want to run blast jobs after we've repeat masked etc.

my @rules       = $ruleAdaptor->fetch_all;
my @jobs;

my @idList;     # All the input ids to check

while (1) {
    
    @jobs = $jobAdaptor->fetch_all;

    foreach my $job(@jobs){
        print $job."\n";die;
        if (($job->status eq 'NEW')   ||
	    (($job->status eq 'FAILED') && ($job->retry_count < $RETRY))){ 
            if ($local){
                $job->run_Locally;
	        }else{
                $job>run_BatchRemote($LSF_params);
            }
        }

    }	    

    #Bio::EnsEMBL::Pipeline::Job->flush_runs($jobAdaptor, $LSF_params);
    #WHAT's THE ABOVE LINE?
    
    exit 0 if $done || $once;
    sleep($SLEEP) if $submitted == 0;
    $completeRead = 0;
    $currentStart = 0;
    @idList = ();
    print "Waking up and run again!\n";
}

# Script for operating the analysis pipeline
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

use Bio::Pipeline::DBSQL::RuleAdaptor;;
use Bio::Pipeline::DBSQL::JobAdaptor;
use Bio::Pipeline::DBSQL::AnalysisAdaptor;
use Bio::Pipeline::DBSQL::DBAdaptor;

# defaults: command line options override pipeConf variables,
# which override anything set in the environment variables.

use Bio::Pipeline::PipeConf qw (DBHOST 
                                DBNAME
                                DBUSER
                                DBPASS
                                QUEUE
                                USENODES
                                BATCHSIZE
                                JOBNAME
                                RETRY
                                SLEEP
			                    );

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
    'flushsize=i' => \$BATCHSIZE,
    'local'       => \$local,
    'idlist=s'    => \$idlist,
    'queue=s'     => \$QUEUE,
    'jobname=s'   => \$JOBNAME,
    'usenodes=s'  => \$USENODES,
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
my $sic         = $db->get_StateInfoContainer;


# scp
# $QUEUE_params - send certain (LSF) parameters to Job. This hash contains
# things QUEUE wants to know, i.e. queue name, nodelist, jobname (things that
# go on the bsub command line), plus the queue flushsize. This hash is
# passed to batch_runRemote which passes them on to flush_runs.
#
# The idea is that you could have more than one of these hashes to suit
# different types of jobs, with different QUEUE options. You would then define
# a queue 'resolver' function. This would take the Job object and return the
# queue type, based on variables in the Job/underlying Analysis object.
#
# For example, you could put slow (e.g., blastx) jobs in a different queue,
# or on certain nodes, or simply label them with a different jobname.

my $QUEUE_params = {};
$QUEUE_params->{'queue'}     = $QUEUE if defined $QUEUE;
$QUEUE_params->{'nodes'}     = $USENODES if $NODES;
$QUEUE_params->{'flushsize'} = $BATCHSIZE if defined $BATCHSIZE;
$QUEUE_params->{'jobname'}   = $JOBNAME if defined $JOBNAME;

# Fetch all the analysis rules.  These contain details of all the
# analyses we want to run and the dependences between them. e.g. the
# fact that we only want to run blast jobs after we've repeat masked etc.

my @rules       = $ruleAdaptor->fetch_all;
my @jobs;

my @idList;     # All the input ids to check

while (1) {
    
    @jobs = $jobAdaptor->fetch_all;

    foreach my $job(@jobs){
   
        if ($job->status eq 'NEW')   ||
	    ( ($job->status eq 'FAILED') && ($job->retry_count < $RETRY) ){ 

            if ($local){
                $job->run_Locally;
	        }else{
                $job>batch_remotely($QUEUE_params);
            }
        }
	    elsif ($job->status eq 'COMPLETED'){
            foreach my $new_job (&create_new_job($job)){
                $new_job->batch_remotely($QUEUE_params);
            }
	    }
	else (DO NOTHING?){
        }

    }	    

    #Bio::EnsEMBL::Pipeline::Job->flush_runs($jobAdaptor, $QUEUE_params);
    
    exit 0 if $done || $once;
    sleep($SLEEP) if $submitted == 0;
    $completeRead = 0;
    $currentStart = 0;
    @idList = ();
    print "Waking up and run again!\n";
}

sub create_new_job{
    my $job = @_;
    my @new_jobs;
    foreach my $rule (@rules){
        if ($rule->condition == $job->analysis->dbID){
            my $new_job = Bio::Pipeline::Job->create_by_analysis_inputId($rule->analysis,$job->input_id);
            push (@new_jobs,$new_job);
        }    
    }    
    return @new_jobs;    
}	

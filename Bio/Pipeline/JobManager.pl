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

use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::BatchSubmission;

# defaults: command line options override pipeConf variables,
# which override anything set in the environment variables.

use Bio::Pipeline::PipeConf qw ( DBHOST 
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

my $local        = 0;       # Run failed jobs locally
my $JOBNAME;                # Meaningful name displayed by bjobs
		            	    # aka "bsub -J <name>"
			                # maybe this should be compulsory, as
			                # the default jobname really isn't any use
my $once;

GetOptions(
    'host=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'flushsize=i' => \$BATCHSIZE,
    'local'       => \$local,
    'queue=s'     => \$QUEUE,
    'jobname=s'   => \$JOBNAME,
    'usenodes=s'  => \$USENODES,
    'once!'       => \$once,
    'retry=i'     => \$RETRY
)
or die ("Couldn't get options");

my $db = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
);

my $jobAdaptor  = $db->get_JobAdaptor;

# scp
# $QUEUE_params - send certain (QUEUE) parameters to Job. This hash contains
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
$QUEUE_params->{'nodes'}     = $USENODES if $USENODES;
$QUEUE_params->{'flushsize'} = $BATCHSIZE if defined $BATCHSIZE;
$QUEUE_params->{'jobname'}   = $JOBNAME if defined $JOBNAME;

#fetching jobs that are have status NEW or 
#have failed with a retry count less than the variable set in PipeConf.


my $run = 1;
while ($run) {

    my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$db);
    my @jobs = $jobAdaptor->fetch_new_failed_jobs($RETRY);
    print STDERR "Running ".scalar(@jobs)."\n";
    
    foreach my $job(@jobs){
        if ($local){
            $job->status('SUBMITTED');
            $job->make_filenames unless $job->filenames;
            $job->update;
            $job->run;
        }else{
            $batchsubmitter->add_job($job);
            if ($job->status eq 'FAILED'){ 
                my $retry_count = $job->retry_count;
                $retry_count++;
                $job->retry_count($retry_count);
            }
            $job->status('BATCHED');
            $job->update;
            $batchsubmitter->submit_batch unless ($batchsubmitter->batched_jobs < $BATCHSIZE);
        }
    }	    

    $batchsubmitter->submit_batch if ($batchsubmitter->batched_jobs);
    
    exit 0 if $once;
    sleep($SLEEP);
    @jobs = $jobAdaptor->fetch_new_failed_jobs($RETRY);
    $run = 0 unless @jobs;
    print "Waking up and run again!\n";
}

print STDERR "exiting jobmanager...\n";

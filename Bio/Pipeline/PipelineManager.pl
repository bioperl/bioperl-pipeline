#!/usr/local/bin/perl

# Script for operating the analysis pipeline
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
# Last modified : 15.06.2001 by Simon Potter
#
# rewritten for bioperl-pipeline <jerm@fugu-sg.org>
#
#
# You may distribute this code under the same terms as perl itself


use strict;
use Getopt::Long;

use Bio::Pipeline::SQL::RuleAdaptor;;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::BatchSubmission;

############################################
#Pipeline Setup
############################################
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
                                WAIT_FOR_ALL_PERCENT
                                TIMEOUT
                                
			                    );

$| = 1;

#my $chunksize    = 500000;  # How many InputIds to fetch at one time
#my $currentStart = 0;       # Running total of job ids
#my $completeRead = 0;       # Have we got all the input ids yet?
my $local        = 0;       # Run failed jobs locally
my $analysis;               # Only run this analysis ids
my $JOBNAME;                # Meaningful name displayed by bjobs
my $pipeline_time = time(); #tracks how long pipeline has been running in seconds
                            #use to see whether timeout has occured
my %pipeline_state;         #hash used to store state of all jobs in the pipeline 

			    # aka "bsub -J <name>"
			    # maybe this should be compulsory, as
			    # the default jobname really isn't any use
my $once =0;
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
    'retry=i'     => \$RETRY,
    'analysis=s'  => \$analysis,
    'wait_for_all_percent=i'=>\$WAIT_FOR_ALL_PERCENT,
    'timeout=s'   => \$TIMEOUT
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
my $inputAdaptor  = $db->get_InputAdaptor;
my $analysisAdaptor = $db->get_AnalysisAdaptor;

###############################
#Pipeline Test
#more sophistication here as we 
#develop more tests
###############################
#Fetch all analysis and for each analysis, run test and setup to ensure
#program exists if specified
#figure out program version if exist
#map the runnable module to the program if not specified
#check db_file exists if not specified

print "Fetching Analysis From Pipeline $DBNAME\n";

my @analysis = $analysisAdaptor->fetch_all;

print scalar(@analysis)." analysis found.\nRunning test and setup..\n\n//////////// Analysis Test ////////////\n";

foreach my $anal (@analysis) {
    $anal->test_and_setup;
}

print "///////////////Tests Completed////////////////////////\n\n";

print "///////////////Starting Pipeline//////////////////////\n";

######################################################################
#Running the Pipeline
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
# Fetch all the analysis rules.  These contain details of all the
# analyses we want to run and the dependences between them. e.g. the
# fact that we only want to run blast jobs after we've repeat masked etc.
######################################################################

my @rules       = $ruleAdaptor->fetch_all;

my $run = 1;
my $submitted;
my $total_jobs;
while ($run) {
    
    my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$db,-queue=>$QUEUE);
    my @jobs = $jobAdaptor->fetch_all;
    if(!$total_jobs) {
        $total_jobs = scalar(@jobs);
    }
    print STDERR "Fetched ".scalar(@jobs)." jobs\n";
    $submitted = 0;

    foreach my $job(@jobs){
   
        if (($job->status eq 'NEW')   || ( ($job->status eq 'FAILED') && ($job->retry_count < $RETRY) )){ 
            $submitted = 1;

            if ($job->status eq 'FAILED'){
                my $retry_count = $job->retry_count;
                $retry_count++;
                $job->retry_count($retry_count);
            }
            if ($local){
                $job->status('SUBMITTED');
                $job->make_filenames unless $job->filenames;
                $job->update;
                $job->run;
  	        }else{
                $batchsubmitter->add_job($job);
                $job->status('SUBMITTED');
                $job->stage ('BATCHED');
                $job->update;
                &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
            }
        }
        elsif ($job->status eq 'COMPLETED'){
            my ($new_jobs) = &create_new_job($job);
            print STDERR "Creating ".scalar(@{$new_jobs})." jobs\n";
            foreach my $new_job (@{$new_jobs}){

                if ($local){
                    $new_job->status('SUBMITTED');
                    $new_job->make_filenames unless $job->filenames;
                    $new_job->update;
                    $new_job->run;
	            }else{
                    $batchsubmitter->add_job($new_job);
                    $new_job->status('SUBMITTED');
                    $new_job->stage('BATCHED');
                    $new_job->update;

                    &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
                }
            }
            $job->remove;
        }
    }

    #submit remaining jobs in batch.
    &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs);

    my $count = $jobAdaptor->job_count($RETRY);
    $run =  0 if ($once || !$count);
    sleep($SLEEP) if ($run && !$submitted);
    #$completeRead = 0;
    #$currentStart = 0;
    print "Waking up and run again!\n";
}

############################
#Utiltiy methods
############################

=head
#used to check whether state of pipeline has changed since last.
sub pipeline_state_changed {
    my (@jobs) = @_;
    foreach my $job(@jobs){
=cut        


sub create_new_job {
    my ($job) = @_;
    my @rules       = $ruleAdaptor->fetch_all;
    my @new_jobs;
    my $action;
    foreach my $rule (@rules){
        if ($rule->current == $job->analysis->dbID){
            my $next_analysis = $analysisAdaptor->fetch_by_dbID($rule->next);
            $action = $rule->action;
            if ($action eq 'NOTHING') {
               print "Rule action : $action\n";
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $inputAdaptor->copy_fixed_input($job->dbID, $new_job->dbID);
               foreach my $input (@inputs) {
                 $new_job->add_input($input);
               }
               push (@new_jobs,$new_job);
            }

            elsif ($action eq 'UPDATE') {
               my @output_ids = $job->_output_ids;
               if (scalar(@output_ids) == 0) {  ## No outputs, so dont create any job 
                  print "No outputs from the previous job, so no job created\n";
               }
               else {
                  foreach my $output_id (@output_ids){
                     my $new_job = $job->create_next_job($next_analysis);
                     my @inputs = $inputAdaptor->copy_fixed_input($job->dbID, $new_job->dbID);
                     foreach my $input (@inputs) {
                       $new_job->add_input($input);
                     }
                     my $new_input = $inputAdaptor->create_new_input($output_id, $new_job->dbID);
                     $new_job->add_input($new_input);
                     push (@new_jobs,$new_job);
                  }
               }
            }

            elsif ($action eq 'WAITFORALL') {
            #waits for all the jobs of this analysis to finish before starting the new job
              if (_check_all_jobs_complete($job)&& !_next_job_created($job, $rule)){
                  my $new_job = $job->create_next_job($next_analysis);
                  my @inputs = $inputAdaptor->copy_fixed_input($job->dbID, $new_job->dbID);
                  foreach my $input (@inputs) {
                     $new_job->add_input($input);
                  }
                  push (@new_jobs,$new_job);
              }
            }

            elsif ($action eq 'WAITFORALL_AND_UPDATE') {
        
              if (_check_all_jobs_complete($job) && !_next_job_created($job, $rule)) {
                  my $new_job = $job->create_next_job($next_analysis);
                  $new_job->status('NEW');
                  $new_job->update;
                  ################  we are not copying the fixed inputs of the previous jobs for now for this option ####################
                  #now copy outputs of all jobs of previous analysis as inputs for this job
                  my @inputs = _update_inputs($job, $new_job);
                  $new_job->add_input(\@inputs);
                  push (@new_jobs,$new_job);
               }
            }

        }
    }
    return (\@new_jobs);
}

sub _get_action_by_next_anal {
    my ($job,@rules) = @_;
    foreach my $rule (@rules){
        if ($rule->next == $job->analysis->dbID){
            return $rule->action;
        }
    }
}
    

sub _update_inputs {
   my ($old_job, $new_job) = @_;
   my @inputs = ();
   my @job_ids = $jobAdaptor->fetch_completed_jobids_by_analysisId_and_processId($old_job->analysis->dbID, $old_job->process_id);   
   #push (@job_ids, $old_job->dbID); 
   my @output_ids = $jobAdaptor->fetch_output_ids(@job_ids);
   foreach my $output_id (@output_ids){
      my $input = $inputAdaptor->create_new_input($output_id, $new_job->dbID);
      push (@inputs, $input);
   }
   return @inputs;
}
 
      

sub _next_job_created {
    my ($job, $rule) = @_;
    my $status = 1;
    my @jobs = $jobAdaptor->fetch_by_analysisId_and_processId($rule->next, $job->process_id);
    my $no = scalar(@jobs);
    if ($no == 0) {
       return 0;
    }
    else {
       return 1;
    }
}


sub _get_waiting_job {
  my (@jobs) = @_;

  my $waiting_job;

  foreach my $job (@jobs) {
     if($job->status eq 'WAIT') {
        $waiting_job = $job;
     }
  }
  return $waiting_job;
}

sub _check_all_jobs_complete {
  my ($job) = @_;
  my $status = 1;
  my @jobs = $jobAdaptor->fetch_by_analysisId_and_processId($job->analysis->dbID, $job->process_id);
  my $nbr = 0;
  foreach my $old_job (@jobs) {
    if ($old_job->status ne 'COMPLETED') {
      $nbr++;
    }
  }
  return $status unless $nbr != 0;
  if(_timeout(\@jobs)){
    if((int($nbr/$total_jobs) * 100) < (100-$WAIT_FOR_ALL_PERCENT)){
      $status = 1;
    }
    else {
      $status = 0;
    }
  }
  else {
      $status = 0;
  }
  
  return $status;
}

#check whether pipeline has timeout with not status changed for more than $TIMEOUT hours
sub _timeout {
  my ($jobs) = @_;
  my $curr_time = time();
  if(_pipeline_state_changed($jobs)){
      $pipeline_time = $curr_time;
  }
  elsif(int(($curr_time - $pipeline_time)/3600) > $TIMEOUT){
      return 1;
  }
  else {}
  return 0;
}

sub _pipeline_state_changed {
    my($jobs) = @_;
    my %last_state = %pipeline_state;
    %pipeline_state = {};
    foreach my $job(@{$jobs}){
      $pipeline_state{$job->status}++;
      $pipeline_state{$job->stage}++;
    }
    foreach my $key (keys %pipeline_state){
      if ($pipeline_state{$key} != $last_state{$key}){
        return 1;
      }
    }
    return 0 
}



sub submit_batch{
	my ($batchsubmitter,$action) = @_;

    eval{
        if ($action){
          $batchsubmitter->submit_batch($action);
        }     
        else {
          $batchsubmitter->submit_batch();
        }

    };
    my $err = $@;
    if ($err){
        my $job_ids;
        foreach my $failed_job($batchsubmitter->get_jobs){
            $failed_job->set_status('FAILED');
            $job_ids .= $failed_job->dbID." ";
        }
        print STDERR "Error submitting jobs with dbIDs $job_ids.\n$err\n Retrying........\n";
    	$batchsubmitter->empty_batch;
    } 
}

#!/usr/local/bin/perl


# Script for operating the analysis pipeline
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
#
# rewritten for bioperl-pipeline <jerm@fugu-sg.org>
#
#
# You may distribute this code under the same terms as perl itself


use strict;
use Getopt::Long;

use Bio::Pipeline::SQL::RuleAdaptor;
use Bio::Pipeline::SQL::InputAdaptor;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::BatchSubmission;



############################################
#Pipeline Setup
############################################
# defaults: command line options override pipeConf variables,

use Bio::Pipeline::PipeConf qw (DBHOST 
                                DBNAME
                                DBUSER
                                DBPASS
                                NFSTMP_DIR
                                QUEUE
                                BATCHSIZE
                                USENODES
                                BATCHSIZE
                                FETCH_JOB_SIZE
                                JOBNAME
                                RETRY
                                SLEEP
                                WAIT_FOR_ALL_PERCENT
                                TIMEOUT
                                
			                    );

$| = 1; #flush all print statements
my $flush        = 0;       #flush is used to check whether to flush all locks on pipeline and disregard  any that exist.
                            #should only be used for debugging.

my $local        = 0;       # Run failed jobs locally
my $resume       = 0;       # Flag to indicate whether resuming or doing a fresh run. 
                            # Used to check whether to do a CREATE_INPUT
my $pipeline_time = time(); #tracks how long pipeline has been running in seconds
                            #use to see whether timeout has occured
my %pipeline_state;         #hash used to store state of all jobs in the pipeline 
my $INPUT_LIMIT = undef;
my $HELP = undef;
my $NUMBER=undef;
my $verbose = 0;

my $USAGE =<<END;
************************************
*PipelineManager.pl
************************************
This is the central script used to run the pipeline.

Usage: PipelineManager.pl 

Options:
Default values are read from PipeConf.pm

     -dbhost The database host name (localhost)
     -dbname The pipeline database name
     -dbpass The password to mysql database
     -flush  flush all locks on pipeline and remove any that exists. 
             Should only be used for debugging or development.
     -batchsize The number ofjobs to be batched to one node
     -local     Whether to run jobs in local mode 
                (on the node where this script is run)
     -number    Number of jobs to run (for testing)
     -queue     Specify the queue on which to submit jobs
     -verbose   Whether to show warning during test and setup
     -help      Display this help

END

GetOptions(
    'dbhost=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'flush'       => \$flush,
    'batchsize=i' => \$BATCHSIZE,
    'local'       => \$local,
    'resume'      => \$resume,
    'queue=s'     => \$QUEUE,
    'usenodes=s'  => \$USENODES,
    'retry=i'     => \$RETRY,
    'wait_for_all_percent=i'=>\$WAIT_FOR_ALL_PERCENT,
    'timeout=s'   => \$TIMEOUT,
    'verbose'     => \$verbose,
    'number=s'    => \$NUMBER,
    'help'        => \$HELP
)
or die $USAGE;

# Lock to prevent two Pipeline Mangers from  connecting to the same DB.
# (i.e. same dbname and dbhost)
#
# Makes directory in $NFSTMP_DIR writes a DBM file in this directory
# which stores useful things like process id/host and the time it
# was started.
#

$HELP && die($USAGE);
$QUEUE = length($QUEUE) > 0 ? $QUEUE:undef;

my $lock_dir = $NFSTMP_DIR . "/.bioperl-pipeline.$DBHOST.$DBNAME";

if (-e $lock_dir && !$flush) {
    # Another pipeline is running: describe it
    my($subhost, $pid, $started,$user) = &running_pipeline($lock_dir);
    $started = scalar localtime $started;

    print STDERR <<EOF;

Error: a pipeline appears to be running!
Created by: $user

    db       $DBNAME\@$DBHOST
    pid      $pid on host $subhost
    started  $started

You cannot have two PipelineMangers connecting to the same database.
The process above must be terminated before this script can be run.
If the process does not exist, remove the lock by executing

    rm -r $lock_dir


Thankyou


EOF
    exit 1;
}
$flush && &remove_lock($lock_dir);
&create_lock($lock_dir, $DBHOST, $$);


my $db = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
);

my $ruleAdaptor     = $db->get_RuleAdaptor;
my $jobAdaptor      = $db->get_JobAdaptor;
my $inputAdaptor    = $db->get_InputAdaptor;
my $analysisAdaptor = $db->get_AnalysisAdaptor;
my $iohAdaptor      = $db->get_IOHandlerAdaptor;


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

print "///////////////Starting Pipeline//////////////////////\n";

print "Fetching Analysis From Pipeline $DBNAME\n";

my @analysis = $analysisAdaptor->fetch_all;

print scalar(@analysis)." analysis found.\nRunning test and setup..\n\n//////////// Analysis Test ////////////\n";

foreach my $anal (@analysis) {
    print STDERR "Checking Analysis ".$anal->dbID. " ".$anal->logic_name;
#    $anal->test_and_setup($verbose);
    print STDERR " ok\n";
}

print "\n///////////////Tests Completed////////////////////////\n\n";


######################################################################
#Running the Pipeline
######################################################################

# Fetch all the analysis rules.  These contain details of all the
# analyses we want to run and the dependences between them. e.g. the
# fact that we only want to run blast jobs after we've repeat masked etc.
my @rules       = $ruleAdaptor->fetch_all;

# Create initial inputs and jobs in bulk if necessary
#&initialise();

#variables
my $run = 1;
my $submitted;
my $total_jobs;
my $nbr_ran;

while ($run) {

    my $new_queue = %Bio::Pipeline::PipeConf::PipeConf->{'QUEUE'};
    $QUEUE = $new_queue || $QUEUE;
    my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$db,-queue=>$QUEUE);

    #Give priority of fetching to new jobs, only fetch FAILED ones once NEW ones are exhausted.
    print STDERR "Fetching Jobs...\n";
    my @incomplete_jobs = $jobAdaptor->fetch_jobs(-number =>$FETCH_JOB_SIZE,-status=>['NEW']);
    if ($#incomplete_jobs < ($FETCH_JOB_SIZE-1)){
        my $nbr_left = $FETCH_JOB_SIZE - (scalar(@incomplete_jobs));
        push @incomplete_jobs, $jobAdaptor->fetch_jobs(-number =>$nbr_left ,-status=>['FAILED']);
    }
    if($#incomplete_jobs < ($FETCH_JOB_SIZE-1)){
        my $nbr_left = $FETCH_JOB_SIZE - (scalar(@incomplete_jobs));
        push @incomplete_jobs, $jobAdaptor->fetch_jobs(-number =>$nbr_left ,-status=>['WAITFORALL']);
    }
    print STDERR "Fetched ".scalar(@incomplete_jobs)." incomplete jobs\n";

    $submitted = 0;

    foreach my $job(@incomplete_jobs){
        
        #check whether output of job needed for downstream analysis
        my $job_depend = $ruleAdaptor->check_dependency_by_job($job,@rules);
        $job->dependency($job_depend);
        
        if ($job->retry_count < $RETRY ){ 
            $submitted = 1;
            
            if ($job->status eq 'FAILED'){
                my $retry_count = $job->retry_count;
                $retry_count++;
                $job->retry_count($retry_count);
            }
            if ($job->status eq 'WAITFORALL'){
              my ($prev_analysis) = $job->analysis->fetch_prev_analysis();
              my $nbr_prev_jobs = $jobAdaptor->get_job_count(-number=>1,
                                                             -analysis_id=>$prev_analysis->dbID,
                                                             -retry_count=>$RETRY);
              my $completed_prev_jobs =  $jobAdaptor->get_completed_job_count(-number=>1,
                                                                              -analysis_id=>$prev_analysis->dbID);
              if (!$nbr_prev_jobs && !$completed_prev_jobs){
                  next;
              }
              #as long as a single job of previous analysis not done yet, don't run
              if($nbr_prev_jobs != 0){
                  next;
              }
            }
            if ($local){
                $job->status('SUBMITTED');
                $job->make_filenames unless $job->filenames;
                $job->update;
                $job->run;
                $nbr_ran++;
                if($NUMBER && ($nbr_ran == $NUMBER)){
                    print "Ran $NUMBER jobs..exiting";
                    exit(1);
                }
  	        }else{
                $batchsubmitter->add_job($job);
                $job->status('SUBMITTED');
                $job->stage ('BATCHED');
                $job->update;
                &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
            }
        }
        else {
            print STDERR "Job ".$job->dbID ." failed ".$job->retry_count." times. Exceed retry limit. Skipping Job...\n";
        }
    }

    #fetch completed jobs for creating new jobs
    my @completed_jobs = $jobAdaptor->fetch_jobs(-number =>$FETCH_JOB_SIZE,-status=>['COMPLETED']);
    print STDERR "Fetched ".scalar(@completed_jobs)." completed jobs\n";
    if($#completed_jobs > 0) {
        print STDERR "Updating Completed Jobs and creating new ones\n";
    }
    
    foreach my $job (@completed_jobs) {
      my ($new_jobs) = &create_new_job($job);
      if(scalar(@{$new_jobs})){
        print STDERR "Creating ".scalar(@{$new_jobs})." jobs\n";
      }
      foreach my $new_job (@{$new_jobs}){

        if ($local){
          $new_job->status('SUBMITTED');
          $new_job->make_filenames unless $job->filenames;
          $new_job->update;
          eval {
            $new_job->run;
          }
	      }
        else{
          $batchsubmitter->add_job($new_job);
          $new_job->status('SUBMITTED');
          $new_job->stage('BATCHED');
          $new_job->update;
          &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
        }
     }
     eval{
			   $job->adaptor->update_completed_job($job);
	 	 };
     my $err;
     if($err = $@){
		  print STDERR ("Error updating completed job\n$err");
     }
      $job->remove;
   }

    #submit remaining jobs in batch.
    &submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs);

    my $count = $jobAdaptor->get_job_count(-retry_count=>$RETRY);

    # exit if there are any more jobs left.
    $run =  0 if (!$count);

    print "Going to snooze for $SLEEP seconds...\n";

    sleep($SLEEP) if ($run && !$submitted);

    print "Waking up and run again!\n";
}

print "Nothing left to run.\n\n///////////////Shutting Down Pipeline//////////////////////\n";

print STDERR "Removing Lock File...\n";
&remove_lock($lock_dir); 
print "Done\n///////////////////////////////////////////////////////////\n";



############################
#Utiltiy methods
############################
#sub create_new_job
#this method creates new jobs taking into account the actions
#in the rule tables to be carried out before the next job is to be created.
#
# COPY_ID      this copys the input name from the job that 
#              just finished to a new input while mapping the new iohandler to this input
#
# COPY_INPUT   this copys the input and the iohandler from the previous job to a new input.
#
# CREATE_INPUT not implemented yet.
#
# UPDATE       this creates new jobs from the new_input table which stores outputs from the previous
#              job and passing in inputs from the previous job as well
#
# WAITFORALL   create a new job only if all jobs of this analysis are done. Inputs to this new job are
#              the inputs from the previous analysis
#
# WAITFORALL_AND_UPDATE  create a new job only if all jobs of this analysis are done. All outputs from jobs
#                       previous analysis are passed as input to this new job. Fixed inputs are not passed.

sub create_new_job {
    my ($job) = @_;
    my @rules       = $ruleAdaptor->fetch_all;
    my @new_jobs;
    my $action;
    foreach my $rule (@rules){
        if (defined ($rule->current) && $rule->current->dbID == $job->analysis->dbID){
            my $next_analysis = $analysisAdaptor->fetch_by_dbID($rule->next->dbID);
            $action = $rule->action;
            if ($action eq 'COPY_ID') {
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $inputAdaptor->copy_inputs_map_ioh($job,$new_job);

               foreach my $input (@inputs) {
                 $new_job->add_input($input);
               }
               push (@new_jobs,$new_job);
            }
            elsif ($action eq 'COPY_INPUT') {
                my $new_job = $job->create_next_job($next_analysis);
                my @inputs = $inputAdaptor->copy_fixed_inputs($job->dbID,$new_job->dbID);
                foreach my $input (@inputs) {
                 $new_job->add_input($input);
                }
                push (@new_jobs,$new_job);
            }
            elsif ($action eq 'UPDATE') {
               my @output_ids = $job->output_ids;
               if (scalar(@output_ids) == 0) {  ## No outputs, so dont create any job 
                  print "No outputs from the previous job, so no job created\n";
               }
               else {
                  foreach my $output_id (@output_ids){
                     my $new_job = $job->create_next_job($next_analysis);
                     my @inputs = $inputAdaptor->copy_fixed_inputs($job->dbID, $new_job->dbID);
                     foreach my $input (@inputs) {
                       $new_job->add_input($input);
                     }
                     my $new_input = $inputAdaptor->create_new_input($output_id, $new_job->dbID);
                     $new_job->add_input($new_input);
                     push (@new_jobs,$new_job);
                  }
               }
            }

           elsif($action eq "WAITFORALL"){
              if (_check_all_jobs_complete($job)&& !_next_job_created($job, $rule)){
               print STDERR "Analysis " .$job->analysis->logic_name ." finished.\n
                               Creating next job\n";
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $inputAdaptor->copy_inputs_map_ioh($job,$new_job);

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
                  my @fixed_inputs = _create_input($next_analysis);
################  we are not copying the fixed inputs of the previous jobs for now for this option ####################
                  #now copy outputs of all jobs of previous analysis as inputs for this job
                  my @new_inputs = _update_inputs($job, $new_job);
                  my @inputs = (@fixed_inputs, @new_inputs);
                  $new_job->add_input(\@inputs);
                  push (@new_jobs,$new_job);
               }
            }


        }
    }
    return (\@new_jobs);
}
##############################
#sub initialise
#this routine checks whether to resume running pipeline from previous runs or to start
#start the pipeline afresh and create inputs if able to.

sub initialise {
        my $init_rule;
        foreach my $rule (@rules) {
           if (! defined($rule->current) && ($rule->action eq 'CREATE_INPUT')) {
              $init_rule = $rule;
              last;
           }
        }
        if (defined ($init_rule)) {
          if (!$jobAdaptor->job_exists($init_rule->next)) {
             print STDERR "Starting fresh pipeline run \n";
             _create_initial_jobs($init_rule->next);
          }
          else {
            print STDERR "Resuming from previous run\n";
          }
        }
}

#creates the initial jobs, used by &initialise
sub _create_initial_jobs {
    my ($analysis) = @_;
    my @inputs = _create_input ($analysis);
    my $jobid = 1;
    my @job_objs;
    foreach my $input (@inputs){
        $input->job_id($jobid);
        my @input_objs;
        push @input_objs, $input;
        my $job = Bio::Pipeline::Job->new(-id => $jobid,
                                              -analysis => $analysis,
                                              -adaptor => $jobAdaptor,
                                              -inputs => \@input_objs);
        $jobAdaptor->store($job);
        $jobid++;
        if($INPUT_LIMIT && $jobid == $INPUT_LIMIT){
            last;}
    }
    print "CREATED Initial jobs!\n";
}

#creates initial inputs
sub _create_input {
    my ($analysis) = @_;
    print "Fetching Input ids \n";
    my $iohs = $analysis->create_input_iohandler;
    my @input_objs;
    foreach my $ioh (@{$iohs}) {
      
    	my ($inputs) = $ioh->fetch_input_ids();
    	my %io_map = %{$analysis->io_map};
    	my $map_ioh = $io_map{$ioh->dbID}; 
    	print scalar(@{$inputs}). " inputs fetched\nStoring...\n";
 
    	foreach my $in (@{$inputs}){
        	my $input_obj = Bio::Pipeline::Input->new(-name => $in,
                                                  -input_handler => $map_ioh);
        	push @input_objs, $input_obj;
    	}
    }
    return @input_objs;
}

#find the next action to do based on current analysis
sub _get_action_by_next_anal {
    my ($job,@rules) = @_;
    foreach my $rule (@rules){
        if ($rule->next->dbID == $job->analysis->dbID){
            return $rule->action;
        }
    }
}
    
#get completed jobs, return new inputs from new_input_table if present
#use for WAITFORALL_AND_UPDATE

sub _update_inputs {
   my ($old_job, $new_job) = @_;
   my @inputs = ();
   my @job_ids = $jobAdaptor->list_completed_jobids(-analysis_id=>$old_job->analysis->dbID, 
                                                    -process_id=>$old_job->process_id);   
   my @output_ids = $jobAdaptor->list_output_ids(@job_ids);
   foreach my $output_id (@output_ids){
      my $input = $inputAdaptor->create_new_input($output_id, $new_job->dbID);
      push (@inputs, $input);
   }
   return @inputs;
}
      
#check whether the next job has been created for the the same process

sub _next_job_created {
    my ($job, $rule) = @_;
    my $status = 1;
    my @jobs = $jobAdaptor->fetch_jobs(-analysis_id=>$rule->next->dbID, -process_id=>$job->process_id);
    my $no = scalar(@jobs);
    if ($no == 0) {
       return 0;
    }
    else {
       return 1;
    }
}

#check whether all jobs for an analysis is completed given a job

sub _check_all_jobs_complete {
  my ($job) = @_;
  my $status = 1;
  if($jobAdaptor->fetch_jobs(-number=>1,-analysis_id=>$job->analysis->dbID,-process_id=>$job->process_id,-status=>["SUBMITTED",'NEW','FAILED'])){
    return 0;
  }
  else {
      return 1;
  }
#  my $nbr = 0;
#  foreach my $old_job (@jobs) {
#    if ($old_job->status ne 'COMPLETED') {
#      $nbr++;
#    }
#  }
#  return $status unless $nbr != 0;
#  if(_timeout(\@jobs)){
#    if((int($nbr/$total_jobs) * 100) < (100-$WAIT_FOR_ALL_PERCENT)){
#      $status = 1;
#    }
#    else {
#      $status = 0;
#    }
#  }
#  else {
#      $status = 0;
#  }
  
#  return $status;
}

#under dev
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

#under dev. 
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

#batch submit the jobs
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

# running pipelines should have lock files in $NFS_TMPDIR/.bioperl-pipeline/.*
sub running_pipeline {
    my ($dir) = @_;
    my %db;

    dbmopen %db, "$dir/db", undef;
    my $host = $db{'subhost'};
    my $name = $db{'pid'};
    my $time = $db{'started'};
    my $user = $db{'user'};
    dbmclose %db;

    return $host, $name, $time,$user;
}


# create lock file in NFS_TMPDIR 
sub create_lock {
    my ($dir, $host, $pid) = @_;
    my %db;

    mkdir $dir, 0777 or die "Can't make lock directory";

    dbmopen %db, "$dir/db", 0666;
    $db{'subhost'} = $host;
    $db{'pid'}     = $pid;
    $db{'started'} = time();
    $db{'user'}    = getlogin();
    dbmclose %db;
}

# remove 'lock' file
sub remove_lock{
    my ($dir) = @_;

    unlink "$dir/db.pag";
    unlink "$dir/db.dir";
    unlink "$dir/db.db";
    unlink "$dir/db";
    rmdir $dir;
}





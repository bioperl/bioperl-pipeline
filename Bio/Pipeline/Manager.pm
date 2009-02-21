#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
#
# rewritten for bioperl-pipeline by <jerm@fugu-sg.org> and <shawnh@fugu-sg.org>
# reassembled into module by <juguang@fugu-sg.org>
# 
# You may distribute this code under the same terms as perl itself

=head1 NAME

Bio::Pipeline::Manager

=head1 SYNOPSIS

  use Bio::Pipeline::Manager;
my $manager = Bio::Pipeline::Manager->new(
    -driver     => $DBI_DRIVER,
    -host       => $DBHOST,
    -dbname     => $DBNAME,
    -user       => $DBUSER,
    -pass       => $DBPASS,
    -flush      => $FLUSH,
    -batchsize  => $BATCHSIZE,
    -local      => $LOCAL,
    -queue      => $QUEUE,
    -retry      => $RETRY,
    -verbose    => $VERBOSE,
    -jobnbr     => $NUMBER,
    -nfstmp_dir => $NFSTMP_DIR,
    -fetch_job_size => $FETCH_JOB_SIZE,
    -sleep      => $SLEEP,
    -batchsize  => $BATCHSIZE,
    -input_limit    => $INPUT_LIMIT
);

  $manager->check_lock;
  $manager->create_lock;
  $manager->test_analysis;
  $manager->run;

=head1 DESCRIPTION

This is a module containing method calls that implement the pipeline control logic.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:
  bioperl-bugs@bio.perl.org
  http://bugzilla.open-bio.org/

=head1 AUTHOR

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::Manager;

use strict;

use Bio::Pipeline::SQL::RuleAdaptor;
use Bio::Pipeline::SQL::InputAdaptor;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::BatchSubmission;
use Bio::Pipeline::Input;         # used in _create_new_job

use Bio::Root::Root;

use vars qw($AUTOLOAD @ISA @autoload_methods);
@ISA = qw(Bio::Root::Root);

BEGIN {
  @autoload_methods = qw( host dbname user db ruleAdaptor jobAdaptor inputAdaptor 
                        analysisAdaptor iohAdaptor nfstmp_dir lock_dir queue 
                        batchsize usenodes fetch_job_size retry sleep batch_submission_obj
                        wait_for_all_percent timeout flush local resume verbose 
                        number input_limit pipeline_time pipeline_state);
}

=head2 new

  Title   : new
  Usage   : my $manager = Bio::Pipeline::Manager->new(
    -driver     => $DBI_DRIVER,
    -host       => $DBHOST,
    -dbname     => $DBNAME,
    -user       => $DBUSER,
    -pass       => $DBPASS,
    -flush      => $FLUSH,
    -batchsize  => $BATCHSIZE,
    -local      => $LOCAL,
    -queue      => $QUEUE,
    -retry      => $RETRY,
    -verbose    => $VERBOSE,
    -jobnbr     => $NUMBER,
    -nfstmp_dir => $NFSTMP_DIR,
    -fetch_job_size => $FETCH_JOB_SIZE,
    -sleep      => $SLEEP,
    -batchsize  => $BATCHSIZE,
    -input_limit    => $INPUT_LIMIT
);
  Function: Constructor for the Manager 
  Returns : L<Bio::Pipeline::Manager>
  Args    : 

=cut

sub new{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    
    my ($host, $dbname, $user, $nfstmp_dir, $queue, $batchsize, $usenodes, 
        $fetch_job_size, $retry, $sleep, $wait_for_all_percent, $timeout,
        $flush, $local, $resume, $verbose, $number)
        = $self->_rearrange(
            [qw(HOST DBNAME USER NFSTMP_DIR QUEUE BATCHSIZE USENODES
            FETCH_JOB_SIZE RETRY SLEEP WAIT_FOR_ALL_PERCENT TIMEOUT
            FLUSH LOCAL RESUME VERBOSE NUMBER)], @args);
    
    $self->host($host);
    $self->dbname($dbname);
    $self->user($user);

    # The following line is neat, since consistent arguments 
    # between this module and Bio::Pipeline::SQL::DBAdaptor.
    my $db = Bio::Pipeline::SQL::DBAdaptor->new(@args) || $self->throw("Couldn't connect to Biopipe database");

    $self->db($db);
    $self->ruleAdaptor($db->get_RuleAdaptor);
    $self->jobAdaptor($db->get_JobAdaptor);
    $self->inputAdaptor($db->get_InputAdaptor);
    $self->analysisAdaptor($db->get_AnalysisAdaptor);
    $self->iohAdaptor($db->get_IOHandlerAdaptor);
    
    $self->nfstmp_dir($nfstmp_dir);
    $self->queue($queue);
    $self->batchsize($batchsize);
    $self->usenodes($usenodes);
    $self->fetch_job_size($fetch_job_size);
    $self->retry($retry);
    $self->sleep($sleep);
    $self->wait_for_all_percent($wait_for_all_percent);
    $self->timeout($timeout);
    $self->flush($flush);
    $self->local($local);
    $self->resume($resume);
    $self->verbose($verbose);
    $self->number($number);
    
    my $lock_dir = "$nfstmp_dir/.biopipe.$host.$dbname";
    $self->lock_dir($lock_dir);
    
    $self->pipeline_time(time());
    return $self;
}


sub AUTOLOAD{
    return if our $AUTOLOAD =~ /::DESTROY$/;
    my ($self, $arg) = @_;
    my $field = $AUTOLOAD;
    $field =~ /::([\w\d]+)$/;
    if(grep /$1/, @autoload_methods){
        $self->{$field} = $arg if defined $arg;
        return $self->{$field};
    }else{
        $self->throw("Can't find the method '$field'");
    }
}

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

sub test_analysis{
    my ($self) = @_;
    my $dbname = $self->dbname;

    my @analysis = $self->analysisAdaptor->fetch_all;
    print scalar(@analysis)." analysis found.\nRunning test and setup..\n\n//////////// Analysis Test ////////////\n";

    foreach my $anal (@analysis) {
        $self->debug("Checking Analysis ".$anal->dbID. " ".$anal->logic_name);
       $anal->test_and_setup($self->verbose);
        $self->debug(" ok\n");
    }
}

=head2 shutdown

  Title   : shutdown
  Usage   : $manager->shutdown
  Function: Shutdown the pipeline, killing jobs and making sure that job states are updated
            appropriately
  Returns : status
  Args    : 

=cut

sub shutdown {
  my ($self) = @_;
  $self->debug("Getting Jobs in queue...\n");
  #only retrieve reading,running and batched jobs, will not kill jobs in writing stage for database consistency
  my @submitted_jobIDs = $self->jobAdaptor->list_queue_ids(-status=>['SUBMITTED'],-stage=>['READING','RUNNING','BATCHED']);
  print scalar(@submitted_jobIDs)." jobs retrieved\nSubmitting kill commands...\n";
  print $submitted_jobIDs[0]."\n";
  my @queue_ids = $self->batch_submission_obj->kill_jobs(@submitted_jobIDs);
  $self->debug("Updating job status as killed\n");
  $self->jobAdaptor->update_killed_job(@queue_ids);

  #get list of jobs in writing stage that were not killed
  my @writing = $self->jobAdaptor->list_queue_ids(-status=>['SUBMITTED'],-stage=>['WRITING']);

  return scalar(@submitted_jobIDs),scalar(@writing);
}

=head2 run

  Title   : run
  Usage   : $manager->run
  Function: run the pipeline, fetches jobs in the pipeline and determines which to run according to rules
  Returns : status
  Args    : 

=cut

sub run{
    my ($self) = @_;
    # Fetch all the analysis rules.  These contain details of all the
    # analyses we want to run and the dependences between them. e.g. the
    # fact that we only want to run blast jobs after we've repeat masked etc.
    
    my @rules = $self->ruleAdaptor->fetch_all;

    # Someone before me comment them out.
    # Create initial inputs and jobs in bulk if necessary
    # $self->_initialise(@rules);
    
    my $FETCH_JOB_SIZE = $self->fetch_job_size;
    my $RETRY = $self->retry;
    my $BATCHSIZE = $self->batchsize;
    my $SLEEP = $self->sleep;
    my $NUMBER = $self->number;
    my $local = $self->local;
    my $run = 1;
    my $submitted;
    my $total_jobs;
    my $nbr_ran;
    
    while ($run) {
        
        eval "require Bio::Pipeline::PipeConf";
        my $new_queue = %Bio::Pipeline::PipeConf::PipeConf->{'QUEUE'};
        $self->queue($new_queue);
        my $batchsubmitter = Bio::Pipeline::BatchSubmission->new( -dbobj=>$self->db,-queue=>$self->queue);
        $self->batch_submission_obj($batchsubmitter);

        #Give priority of fetching to new jobs, only fetch FAILED ones once NEW ones are exhausted.
        $self->debug("\nFetching Jobs...\n");
        my @incomplete_jobs = $self->jobAdaptor->fetch_jobs(-number =>$FETCH_JOB_SIZE,-status=>['NEW']);
        if ($#incomplete_jobs < ($FETCH_JOB_SIZE-1)){
            my $nbr_left = $FETCH_JOB_SIZE - (scalar(@incomplete_jobs));
            push @incomplete_jobs, $self->jobAdaptor->fetch_jobs(-number =>$nbr_left ,-status=>['FAILED','KILLED']);
        }
        if($#incomplete_jobs < ($FETCH_JOB_SIZE-1)){
            my $nbr_left = $FETCH_JOB_SIZE - (scalar(@incomplete_jobs));
            push @incomplete_jobs, $self->jobAdaptor->fetch_jobs(-number =>$nbr_left ,-status=>['WAITFORALL']);
        }
        $self->debug("\nFetched ".scalar(@incomplete_jobs)." incomplete jobs\n");

        $submitted = 0;

        foreach my $job(@incomplete_jobs){
        
            #check whether output of job needed for downstream analysis
            my $job_depend = $self->ruleAdaptor->check_dependency_by_job($job,@rules);
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
                    my $nbr_prev_jobs = $self->jobAdaptor->get_job_count(-number=>1,
                                                             -analysis_id=>$prev_analysis->dbID,
                                                             -retry_count=>$RETRY);
                    my $completed_prev_jobs =  $self->jobAdaptor->get_completed_job_count(-number=>1,
                                                                              -analysis_id=>$prev_analysis->dbID);
                    next if (!$nbr_prev_jobs && !$completed_prev_jobs);
                    
                    #as long as a single job of previous analysis not done yet, don't run
                    
                    next if($nbr_prev_jobs != 0);
                }
                if ($local){
                    $job->status('SUBMITTED');
                    $job->make_filenames unless $job->filenames;
                    $job->update;
                    $job->run_local;
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
                    $self->_submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
                }
            }
            else {
                $self->debug("Job ".$job->dbID ." failed ".$job->retry_count." times. Exceed retry limit. Skipping Job...\n");
            }
        }

        #fetch completed jobs for creating new jobs
        my @completed_jobs = $self->jobAdaptor->fetch_jobs(-number =>$FETCH_JOB_SIZE,-status=>['COMPLETED']);
        $self->debug( "\nFetched ".scalar(@completed_jobs)." completed jobs\n");
        if($#completed_jobs > 0) {
            $self->debug("Updating Completed Jobs and creating new ones\n");
        }
    
        foreach my $job (@completed_jobs) {
            my ($new_jobs) = $self->_create_new_job($job);
            if(scalar(@{$new_jobs})){
                $self->debug("Creating ".scalar(@{$new_jobs})." jobs\n");
            }
            foreach my $new_job (@{$new_jobs}){

                if ($local){
                    $new_job->status('SUBMITTED');
                    $new_job->make_filenames unless $job->filenames;
                    $new_job->update;
                    $new_job->run_local;
	            }else{
                    $batchsubmitter->add_job($new_job);
                    $new_job->status('SUBMITTED');
                    $new_job->stage('BATCHED');
                    $new_job->update;
                    $self->_submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs >= $BATCHSIZE);
                }
            }
            eval{
		        $job->adaptor->update_completed_job($job);
	 	    };

	    	$self->debug("Error updating completed job\n$@\n") if($@);
            
        $job->remove;
        }

        #submit remaining jobs in batch.
        $self->_submit_batch($batchsubmitter) if ($batchsubmitter->batched_jobs);

        my $count = $self->jobAdaptor->get_job_count(-retry_count=>$RETRY);

        # exit if there are any more jobs left.
        $run =  0 if (!$count);

        print "Going to snooze for $SLEEP seconds...\n";

        sleep($SLEEP) if ($run && !$submitted);

        print "Waking up and run again!\n";
    }

    print "Nothing left to run.\n\n///////////////Shutting Down Pipeline//////////////////////\n";
    return 1;

} # End of run

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

sub _create_new_job {
    my ($self, $job) = @_;
    my @rules       = $self->ruleAdaptor->fetch_all;
    my @new_jobs;
    my $action;
    foreach my $rule (@rules){
        if (defined ($rule->current) && $rule->current->dbID == $job->analysis->dbID){
            my $next_analysis = $self->analysisAdaptor->fetch_by_dbID($rule->next->dbID);
            $action = $rule->action;
            if ($action eq 'COPY_ID') {
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $self->inputAdaptor->copy_inputs_map_ioh($job,$new_job);

               foreach my $input (@inputs) {
                 $new_job->add_input($input);
               }
               push (@new_jobs,$new_job);
            }
            elsif($action eq 'COPY_OUTPUT_ID'){
                my $new_job = $job->create_next_job($next_analysis);
                foreach my $out_id($job->output_ids){
                    my $input = Bio::Pipeline::Input->new(-name=>$out_id);
                    $new_job->add_input($input);
                }
                push (@new_jobs,$new_job);
            }
            elsif($action eq 'COPY_ID_FILE'){
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $self->inputAdaptor->copy_inputs_map_ioh($job,$new_job,'infile');

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
                     my @inputs = $self->inputAdaptor->copy_fixed_inputs($job->dbID, $new_job->dbID);
                     foreach my $input (@inputs) {
                       $new_job->add_input($input);
                     }
                     my $new_input = $self->inputAdaptor->create_new_input($output_id, $new_job->dbID);
                     $new_job->add_input($new_input);
                     push (@new_jobs,$new_job);
                  }
               }
            }

           elsif($action eq "WAITFORALL"){
              if ($self->_check_all_jobs_complete($job)&& !$self->_next_job_created($job, $rule)){
               $self->debug("Analysis " .$job->analysis->logic_name ." finished.\n
                               Creating next job\n");
               my $new_job = $job->create_next_job($next_analysis);
               my @inputs = $self->inputAdaptor->copy_inputs_map_ioh($job,$new_job);

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
} # End of create_new_job

##############################
#sub initialise
#this routine checks whether to resume running pipeline from previous runs or to start
#start the pipeline afresh and create inputs if able to.

sub _initialise {
    my ($self, @rules) = @_;
    my $init_rule;
    foreach my $rule (@rules) {
        if (! defined($rule->current) && ($rule->action eq 'CREATE_INPUT')) {
            $init_rule = $rule;
            last;
        }
    }
    if (defined ($init_rule)) {
        if (!$self->jobAdaptor->job_exists($init_rule->next)) {
            $self->debug("Starting fresh pipeline run \n");
            _create_initial_jobs($init_rule->next);
        }else {
            $self->debug("Resuming from previous run\n");
        }
    }
}

#find the next action to do based on current analysis
sub _get_action_by_next_anal {
    my ($self, $job,@rules) = @_;
    foreach my $rule (@rules){
        if ($rule->next->dbID == $job->analysis->dbID){
            return $rule->action;
        }
    }
}
    
#get completed jobs, return new inputs from new_input_table if present
#use for WAITFORALL_AND_UPDATE

sub _update_inputs {
   my ($self, $old_job, $new_job) = @_;
   my @inputs = ();
   my @job_ids = $self->jobAdaptor->list_completed_jobids(-analysis_id=>$old_job->analysis->dbID, 
                                                    -process_id=>$old_job->process_id);   
   my @output_ids = $self->jobAdaptor->list_output_ids(@job_ids);
   foreach my $output_id (@output_ids){
      my $input = $self->inputAdaptor->create_new_input($output_id, $new_job->dbID);
      push (@inputs, $input);
   }
   return @inputs;
}
      
#check whether the next job has been created for the the same process

sub _next_job_created {
    my ($self, $job, $rule) = @_;
    my $status = 1;
    my @jobs = $self->jobAdaptor->fetch_jobs(-analysis_id=>$rule->next->dbID, -process_id=>$job->process_id);
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
  my ($self, $job) = @_;
  my $status = 1;
  if($self->jobAdaptor->fetch_jobs(-number=>1,-analysis_id=>$job->analysis->dbID,-process_id=>$job->process_id,-status=>["SUBMITTED",'NEW','FAILED','KILLED'])){
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
  my ($self, $jobs) = @_;
  my $curr_time = time();
  if(_pipeline_state_changed($jobs)){
      $self->pipeline_time($curr_time);
  }
  elsif(int(($curr_time - $self->pipeline_time)/3600) > $self->timeout){
      return 1;
  }
  else {}
  return 0;
}

#under dev. 
sub _pipeline_state_changed {
    my($self, $jobs) = @_;
    my %last_state = %{$self->pipeline_state};
    my %pipeline_state = {};
    foreach my $job(@{$jobs}){
      $pipeline_state{$job->status}++;
      $pipeline_state{$job->stage}++;
    }
    $self->pipeline_state(\%pipeline_state);
    foreach my $key (keys %pipeline_state){
      if ($pipeline_state{$key} != $last_state{$key}){
        return 1;
      }
    }
    return 0 
}

#batch submit the jobs
sub _submit_batch{
    my ($self, $batchsubmitter, $action) = @_;

   # eval{ $batchsubmitter->submit_batch($action); };
    eval{
       if ($action){
         $batchsubmitter->submit_batch($action);
        }     
      else {
        $batchsubmitter->submit_batch();
       }

     };
                                                                        
    if ($@){
        my $job_ids;
        foreach my $failed_job($batchsubmitter->get_jobs){
            $failed_job->set_status('FAILED');
            $job_ids .= $failed_job->dbID." ";
        }
        $self->debug("Error submitting jobs with dbIDs $job_ids.\n$@\n Retrying........\n");
    	$batchsubmitter->empty_batch;
    } 
}


=head1 LOCKING

Lock to prevent two or more piepline manager processes from connecting to 
the same pipeline database (i.e. same dbhost and dbname)

Makes directory in $NFSTMP_DIR writes a DBM file in this directory 
which stores useful information like process id, host and 
the time it was started.

=cut

# running pipelines should have lock files in $NFS_TMPDIR/.bioperl-pipeline/.*
# This sub have been named as running_pipeline
sub _read_lock {
    my ($self, $dir) = @_;
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
    my ($self) = @_;
    my %db;
    my $dir = $self->lock_dir;
  
    mkdir $dir, 0777 or $self->throw("Can't make lock directory $dir");

    dbmopen %db, "$dir/db", 0666;
    $db{'subhost'} = $self->host;
    $db{'pid'}     = $$;
    $db{'started'} = time();
    $db{'user'}    = getlogin();
    dbmclose %db;
    return $dir;
}

# remove 'lock' file
sub remove_lock{
    my ($self) = @_;

    $self->debug("Removing Lock File...\n");
    my $dir = $self->lock_dir;
    unlink "$dir/db.pag";
    unlink "$dir/db.dir";
    unlink "$dir/db.db";
    unlink "$dir/db";
    rmdir $dir;
    print "Done\n///////////////////////////////////////////////////////////\n";
}

sub check_lock{
    my ($self) = @_;
    my $dir = $self->lock_dir;
    if(-e $dir && !$self->flush){
        # Another pipeline with the same pipeline db is runng.
        my $dbhost = $self->host;
        my $dbname = $self->dbname;
        
        my ($host, $pid, $started, $user ) = $self->_read_lock;
        $started = scalar localtime $started;

        print STDERR <<EOF;

Error: another pipeline appears to be running!
Created by : $user
db  $dbname\@$dbhost
pid $pid on host $host
started $started

You cannot have two pieline managers connecting to the same database.
The process above must be terminated before this script can be run.
If the process does not exist, rmove the lock by executing 

rm -r $dir

Thanks

EOF
        exit 1;
    }

    $self->flush && $self->remove_lock;
}

1;    
=head2 pipeline_time

A getter/setter

tracks how long pipeline has been running in seconds
use to see whether timeout has occured

Implemented in AUTOLOAD
Used in sub timeout

=head2 pipeline_state

hash used to store state of all jobs in the pipeline

=cut


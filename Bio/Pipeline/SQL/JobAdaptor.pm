# BioPerl module for Bio::Pipeline::SQL::JobAdaptor
#
# Adapted from Arne Stabenau EnsEMBL JobAdaptor
#
# 20/10/2002 Refactored by Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::JobAdaptor 

=head1 SYNOPSIS

  $jobAdaptor = $dbobj->get_JobAdaptor;
  $jobAdaptor = $jobobj->adaptor;
  my @jobs = $jobAdaptor->fetch_jobs(-number=>1000,
                                     -analysis_id=>1,
                                     -status=>['FAILED','NEW'],
                                     -stage =>['WRITING'],
                                     -retry_count=> 10,
                                     -process_id=>'NEW');
  my $job_count = $jobAdptor->get_job_count(-analysis_id=>1,
                                            -status=>['FAILED']);



=head1 DESCRIPTION

Module to encapsulate all db access for persistent class Job.
There should be just one per application and database connection.


=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::SQL::JobAdaptor;

use Bio::Pipeline::Job;
use Bio::Pipeline::SQL::InputAdaptor;
use Bio::Root::Root;
use Bio::Pipeline::IOHandler;
use vars qw(@ISA %VALID_STATUS %VALID_STAGE);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);

BEGIN {
    %VALID_STATUS = ('NEW'=>1,'FAILED'=>1,'SUBMITTED'=>1,'COMPLETED'=>1,'WAITFORALL'=>1,'KILLED'=>1);
    %VALID_STAGE  = ('READING'=>1,'WRITING'=>1,'RUNNING'=>1,'BATCHED'=>1);
}

################################################################################
#This Adaptor is getting big.
#Sectionalizing the different method calls into the following:
# -methods that return jobs (object methods)
# -methods that return ids  (id methods)
# -methods that return boolean about some state of the job table (state methods)
################################################################################


##############################
#Object Methods
##############################

=head2 fetch_by_dbID

  Title   : fetch_by_dbID
  Usage   : my $job = $adaptor->fetch_by_dbID
  Function: Retrieves a job from database by internal id
  Returns : throws exception when something goes wrong.
            undef if the id is not in the db.
  Args    : the dbid

=cut

sub fetch_by_dbID {
  my $self = shift;
  my $id = shift;
  my $job;

  my $sth = $self->prepare( q{
   SELECT job_id,hostname,rule_group_id, process_id, analysis_id, queue_id, object_file,
      stdout_file, stderr_file, retry_count,status,stage
    FROM job
    WHERE job_id = ? } );
  
  $sth->execute( $id );

  my $hashref = $sth->fetchrow_hashref;

  if( ! defined $hashref ) {
    return undef;
  }

  my $analysis = 
    $self->db->get_AnalysisAdaptor->
      fetch_by_dbID( $hashref->{analysis_id} );

  # getting the inputs
  my @inputs= $self->db->get_InputAdaptor->fetch_inputs_by_jobID($id);


  # gettting the outputs if any
  # No output adaptor for the moment, so sql stuff goes here
  my $query = "SELECT output_name 
            FROM output
            WHERE job_id = $id";
  $sth = $self->prepare($query);
  $sth->execute;
  my @outputs;
  while (my ($output_id) = $sth->fetchrow_array){
      push (@outputs,$output_id);
  }


  $job = Bio::Pipeline::Job->new
  (
   '-dbobj'    => $self->db,
   '-adaptor'  => $self,
   '-hostname' =>$hashref->{'hostname'},
   '-id'       => $hashref->{'job_id'},
   '-rule_group_id'=>$hashref->{'rule_group_id'},
   '-process_id' => $hashref->{'process_id'},
   '-queue_id' => $hashref->{'queue_id'},
   '-inputs'   => \@inputs,
   '-stdout'   => $hashref->{'stdout_file'},
   '-stderr'   => $hashref->{'stderr_file'},
   '-input_object_file' => $hashref->{'object_file'},
   '-analysis' => $analysis,
   '-retry_count' => $hashref->{'retry_count'},
   '-stage'     => $hashref->{'stage'},
   '-status'    => $hashref->{'status'},
   '-output_ids'   => \@outputs
  );

  return $job;
}


=head2 fetch_jobs 

  Title   : fetch_jobs
  Usage   : my @jobs = $adaptor->fetch_jobs(-number=>100, -status=>['NEW','FAILED'],-stage=>['WRITING']);
  Function: Flexible method used for fetching jobs based on status or stage. Behavior is as such
            each tag of status will be treated as an OR property. Likewise for stage.
            Each set of tag between stage and status will be treated with the AND property.
            So for this example, it will be WHERE ((status="NEW" OR status="FAILED") AND (stage="WRITING")) 
  Returns : Array of L<Bio::Pipeline::Job> 
  Args    : -number: Number of jobs to limit for the fetch
            -status: The list of status types (allowed: NEW,FAILED,BATCHED,COMPLETED)
            -stage : The list of stage types (allowed: READING, WRITING,RUNNING)
            -analysis_id: The analysis id of the jobs
            -process_id: The process ids of the jobs

=cut

sub fetch_jobs{
    my ($self,@args) = @_;

    my @jobs;
    #prepare the query

    my $query =" SELECT job_id, hostname, process_id, analysis_id,rule_group_id, queue_id, object_file,
                        stdout_file, stderr_file, retry_count,status,stage
                FROM job";
    $query .= $self->_make_query_conditional(-table=>"job",@args);

    #Get the jobs
    my $sth = $self->prepare($query);
    $sth->execute;
    
    while (my ($job_id, $hostname,$process_id, $analysis_id,$rule_group_id, $queue_id, $object_file,
               $stdout_file, $stderr_file, $retry_count, $status, $stage ) = $sth->fetchrow_array){

      my $analysis = $self->db->get_AnalysisAdaptor-> fetch_by_dbID( $analysis_id );

     # getting the inputs
      my @inputs= $self->db->get_InputAdaptor->fetch_inputs_by_jobID($job_id);

      # gettting the outputs if any
      my $query1 = "SELECT output_name
              FROM output
              WHERE job_id = $job_id";
      my $sth1 = $self->prepare($query1);
      $sth1->execute;
      my @outputs;
      while (my ($output_id) = $sth1->fetchrow_array){
         push (@outputs,$output_id);
      }

      my $job = Bio::Pipeline::Job->new
       (
       '-dbobj'       => $self->db,
       '-adaptor'     => $self,
       '-id'          => $job_id,
       '-hostname'    => $hostname,
       '-rule_group_id'=>$rule_group_id,
       '-process_id'  => $process_id,
       '-queue_id'    => $queue_id,
       '-inputs'      => \@inputs,
       '-stdout'      => $stdout_file,
       '-stderr'      => $stderr_file,
       '-input_object_file' => $object_file,
       '-analysis'    => $analysis,
       '-retry_count' => $retry_count,
       '-stage'       => $stage,
       '-status'      => $status,
       '-output_ids'   => \@outputs
      );
      push (@jobs,$job);
    }
    return @jobs;
}


#########################################################
#list id methods
#########################################################

=head2 list_output_ids

  Title   : list_output_ids
  Usage   : my @jobs = $adaptor->list_output_ids(@jobs_ids)
  Function: returns the list of output ids given an array of job ids
  Returns : Array of scalar ids
  Args    : Array of job ids

=cut

sub list_output_ids {
  my ($self, @job_ids) = @_;

  my @output_ids = ();

  foreach my $job_id (@job_ids) {
    my $query = "SELECT output_name
                 FROM output
                 WHERE job_id = $job_id";
    my $sth = $self->prepare($query);
    $sth->execute;
    while (my ($output_id) = $sth->fetchrow_array){
        push (@output_ids, $output_id);
    }
  }
  return @output_ids;
}

=head2 list_job_ids

  Title   : list_all_job_ids
  Usage   : my @jobs = $adaptor->list_all_job_ids()
  Function: Flexible method used for fetching job ids based on status or stage. Behavior is as such
            each tag of status will be treated as an OR property. Likewise for stage.
            Each set of tag between stage and status will be treated with the AND property.
            So for this example, it will be WHERE ((status="NEW" OR status="FAILED") AND (stage="WRITING")) 
            Works on the job table
  Returns : Array of job ids 
  Args    : -number: Number of jobs to limit for the fetch
            -status: The list of status types (allowed: NEW,FAILED,BATCHED,COMPLETED)
            -stage : The list of stage types (allowed: READING, WRITING,RUNNING)
            -analysis_id: The analysis id of the jobs
            -process_id: The process ids of the jobs

=cut

sub list_job_ids {
    my ($self,@args)  = @_;

    my @jobs;
    #prepare the query

    my $query =" SELECT job_id
                 FROM job";
    $query.= $self->_make_query_conditional(-table=>'job',@args);

    #Get the jobs
    my $sth = $self->prepare($query);
    $sth->execute;

    my @job_id;
 
    while (my ($job_id) = $sth->fetchrow_array){

      push @job_id,$job_id;
    }
    return @job_id;
}


sub list_queue_ids {
    my ($self,@args)  = @_;

    my @jobs;
    #prepare the query

    my $query =" SELECT queue_id
                 FROM job";
    $query.= $self->_make_query_conditional(-table=>'job',@args);
    #Get the jobs
    my $sth = $self->prepare($query);
    $sth->execute;

    my @job_id;
 
    while (my ($job_id) = $sth->fetchrow_array){

      push @job_id,$job_id;
    }
    return @job_id;
}

=head2 list_completed_job_ids

  Title   : list_completed_job_ids
  Usage   : my $query = $adaptor->list_completed_job_ids()
  Function: Utility method for creating the WHERE clause for job table query.
            Works on the completed_jobs table
  Returns : String
  Args    : -dbid  : The job dbid
            -number: Number of jobs to limit for the fetch
            -analysis_id: The analysis id of the jobs
            -process_id: The process ids of the jobs

=cut

sub list_completed_job_ids {
  my ($self,@args) = @_;


  my $query = " SELECT completed_job_id
                FROM completed_jobs ";

  $query .= $self->_make_query_conditional(-table=>"completed_jobs",@args);


  my $sth = $self->prepare($query);
  $sth->execute();
  my @job_ids;

  while (my ($job_id) = $sth->fetchrow_array) {
     push (@job_ids, $job_id);
  }
  return @job_ids;
}

###########################################################
#Info Methods
###########################################################

=head2 job_exists

  Title   : job_exists
  Usage   : my @jobs = $adaptor->job_exists()
  Function: Check where a job exists in the job or completed_jobs table given an analysis object
  Returns : True/False
  Arg     : L<Bio::Pipeline::Analysis>

=cut

sub job_exists {
  my $self = shift;
  my $analysis = shift;

  my $analysis_id = $analysis->dbID;

  my $query = " SELECT count(*)
                FROM job
                WHERE analysis_id = $analysis_id " ;
  my $sth = $self->prepare($query);
  $sth->execute();
  my ($job_count) = $sth->fetchrow_array ;

  $query = " SELECT count(*)
                FROM completed_jobs
                WHERE analysis_id = $analysis_id " ;
  $sth = $self->prepare($query);
  $sth->execute();
  my ($completed_job_count) = $sth->fetchrow_array ;

  if ($job_count || $completed_job_count) {
     return 1;
  }
  else {
     return 0;
  }
}

=head2 get_job_count

  Title   : get_job_count
  Usage   : my @jobs = $adaptor->get_job_count()
  Function: Get count of job by various criteria 
            Works on the job table
  Returns : A job count number
  Arg     : -status: The list of status types (allowed: NEW,FAILED,BATCHED,COMPLETED)
            -stage : The list of stage types (allowed: READING, WRITING,RUNNING)
            -analysis_id: The analysis id of the jobs
            -process_id: The process ids of the jobs
            -retry_count: The retry count of the jobs

=cut

sub get_job_count{
    my ($self,@args) = @_;
    
    my $query = "SELECT count(*) FROM job";

    $query.=$self->_make_query_conditional(@args);

    my $sth = $self->prepare($query);
    $sth->execute;

    my ($count) = $sth->fetchrow_array;
    return $count;
}

sub get_completed_job_count {
    my ($self,@args) = @_;
    my $query = "SELECT count(*) FROM completed_jobs";
    $query.=$self->_make_query_conditional(-table=>"completed_jobs",@args);

    my $sth = $self->prepare($query);
    $sth->execute;

    my ($count) = $sth->fetchrow_array;
    return $count;
}



###############################
#Store/Remove/Update methods
###############################

=head2 store

  Title   : store
  Usage   : $job->store
  Function: puts a job in the db and gives it an internal id
            expects analysis to be already in db.
  Returns : throws exception when something goes wrong.
  Args    : 

=cut

sub store {
  my $self = shift;
  my $job = shift;

  if ( !defined ($job->dbID)) {

   if( ! defined( $job->analysis->dbID )) {
     $self->throw( "Need to store analysis first" );
   }

   my $sth = $self->prepare( q{
     INSERT into job( analysis_id,rule_group_id,
       stdout_file, stderr_file, object_file,
       status,time) 
       VALUES ( ?, ?, ?,?, ?, ?, now() ) } );

   my $status = $job->status || "NEW";
   $sth->execute( $job->analysis->dbID,
                  $job->rule_group_id,
                  $job->stdout_file,
                  $job->stderr_file,
                  $job->input_object_file,
                  $status);

   $sth = $self->prepare( "SELECT LAST_INSERT_ID()" );
   $sth->execute;

   my $dbId = ($sth->fetchrow_arrayref)->[0];
   $job->dbID( $dbId );
   $job->adaptor( $self );
  }
  else {
   if( ! defined( $job->analysis->dbID )) {
     $self->throw( "Need to store analysis first" );
   }

   my $sth = $self->prepare( q{
     INSERT into job( job_id, analysis_id,
       stdout_file, stderr_file, object_file,
       status,time)
     VALUES ( ?, ?, ?, ?, ?, ?, now() ) } );

   $sth->execute($job->dbID, 
                 $job->analysis->dbID,
                 $job->stdout_file,
                 $job->stderr_file,
                 $job->input_object_file,
                 'NEW');

   $job->adaptor( $self );
  }
  
  my $input_adaptor = $self->db->get_InputAdaptor;

  foreach my $input($job->inputs) {
    $input->job_id($job->dbID);
    $input_adaptor->store_fixed_input($input);
  }

  return $job->dbID;

}

=head2 store_outputs

  Title   : store_outputs
  Usage   : my @jobs = $adaptor->store_outputs($job,@output_ids)
  Function: store a list of outputids keyed by a job into the output table 
  Returns : 

=cut

sub store_outputs {
 my ($self,$job,@output_ids) = @_;

 my $sth;
 my $query;
 my $job_id = $job->dbID;

 foreach my $output_id(@output_ids) {
   $query = "   INSERT into output (job_id,output_name)
                    VALUES ($job_id, $output_id)"; 
   $sth = $self->prepare($query);
   $sth->execute;
 }
}

=head2 remove

  Title   : remove
  Usage   : $jobadaptor->remove( $job )
  Function: deletes entries for job from database tables.
            deletes also history of status.
  Returns : throws exception when something goes wrong.
  Args    : 

=cut

sub remove {
  my $self = shift;
  my $job = shift;

  if( ! defined $job->dbID ) {
    $self->throw( "Cant remove job without dbID" );
  }
  my $dbID = $job->dbID;

  my $sth = $self->prepare( qq{
    DELETE FROM job
     WHERE job_id = $dbID } );
  $sth->execute;
}


=head2 remove_by_dbID

  Title   : remove_by_dbID
  Usage   : $jobadaptor->remove_by_dbID( $dbID )
  Function: deletes entries for job from database tables.
            deletes also history of status. Can take a list of ids.
  Returns : throws exception when something goes wrong.
  Args    : 

=cut

sub remove_by_dbID {
  my $self = shift;
  my @dbIDs = @_;
  
  if( $#dbIDs == -1 ) { return }
  
  my $inExpr = "(".join( ",",@dbIDs ).")";
  
  my $sth = $self->prepare( qq{
    DELETE FROM job
     WHERE job_id IN $inExpr } );
  eval {
    $sth->execute;
  };if($@){$self->throw("Error encountered trying to remove jobs $inExpr.\n$@");} 

}

=head2 update

  Title   : update
  Usage   : $job->update; $jobAdaptor->update( $job )
  Function: a job which is already in db can update its contents
            it only updates stdout_file, stderr_file, retry_count
            and queue_id
  Returns : throws exception when something goes wrong.
  Args    : 

=cut

sub update {
  my $self = shift;
  my $job = shift;
  
  # only stdout, stderr, retry, queue_id and status are likely to be updated

  my $sth = $self->prepare( q{
    UPDATE job
       SET hostname=?,
           stdout_file = ?,
           stderr_file = ?,
           object_file = ?,
           retry_count = ?,
           queue_id = ?,
           stage = ?,
           status = ?,
           process_id = ?
     WHERE job_id = ? } );
  eval {
  $sth->execute($job->hostname,
     $job->stdout_file,
		 $job->stderr_file,
		 $job->input_object_file,
		 $job->retry_count,
		 $job->queue_id,
		 $job->stage,
		 $job->status,
     $job->process_id,
		 $job->dbID );
  };if ($@) { $self->throw("ATTEMPT TO UPDATE JOB FAILED.\n.$@");}
}

=head2 update_killed_job

  Title   : update_killed_job;
  Usage   : $job->update_killed_job; 
  Function: Given a set of job queue ids, it updates their status as KILLED
            Usually called during a pipeline termination procedure
  Returns : 
  Args    : A list of queue ids

=cut

sub update_killed_job {
  my ($self,@queue_ids) = @_;
  $self->throw("No queue ids provided") unless $#queue_ids >=0;
  my $query = "UPDATE job set STATUS='KILLED'  WHERE queue_id IN (".join(',',@queue_ids).")";
  my $sth = $self->prepare($query);
  eval {
    $sth->execute();
  }; 
  if($@) {
    $self->throw("Couldn't update killed jobs status");;
  }
}

=head2 update_completed_job

  Title   : update_completed_job;
  Usage   : $job->update_complete; $jobAdaptor->update_completed( $job )
  Function: moves job record from the job table to the completed_jobs table
            This step is optional, but it keeps a record of the completed jobs
  Returns : throws exception when something goes wrong.
  Args    : 

=cut

sub update_completed_job {
  my $self = shift;
  my $job = shift;

  $self->throw("Can't update a completed job that has no dbID!") unless (defined $job->dbID);
  my $query = " INSERT INTO completed_jobs VALUES(?,?,?,?,?,?,?,?,?,?,?)";
  
  my $sth = $self->prepare($query);
#  $self->warn($query);

  eval { 
      $sth->execute($job->dbID,$job->process_id,$job->analysis->dbID,$job->rule_group_id,$job->queue_id,$job->hostname,$job->stdout_file,
                    $job->stderr_file,$job->input_object_file,'now()',$job->retry_count);
  };if ($@) { $self->throw("ATTEMPT TO UPDATE COMLETED JOB FAILED.\n.$@");}

  return 1;
}

sub remove_completed_jobs_by_job {
    my ($self,$job) = @_;
    if(!$job){
        my $sth = $self->prepare("DELETE FROM completed_jobs");
        $sth->execute();
    }
    else {
        $job->dbID || $self->throw("job has no dbID, can't remove");
        my $sth = $self->prepare("DELETE FROM completed_jobs WHERE completed_job_id=?");
        $sth->execute($job->dbID);
    }
    return;
}

=head2 set_status

  Title   : set_status
  Usage   : my $status = $job->set_status
  Function: Sets the job status
  Returns : nothing
  Args    : Pipeline::Job Bio::Pipeline::Status

=cut

sub set_status {
    my ($self,$job) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }

    eval {	
	    my $sth = $self->prepare(   "update job set status='".$job->status."',time=now()
                                    where job_id = ".$job->dbID);
	    $sth->execute();
    };
	
    if ($@) {
	    $self->throw("Error setting status for job ".$job->dbID);
    } 
}
sub set_analysis_id{
    my ($self,$job,$id) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }

    eval {	
	    my $sth = $self->prepare(   "update job set analysis_id='".$id."',time=now()
                                    where job_id = ".$job->dbID);
	    $sth->execute();
    };
	
    if ($@) {
	    $self->throw("Error setting analysis_id for job ".$job->dbID);
    } 
}


=head2 set_stage

  Title   : set_stage
  Usage   : my $stage = $job->set_stage
  Function: Sets the job stage
  Returns : nothing
  Args    : 

=cut

sub set_stage {
    my ($self,$job) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }


    eval {	
	    my $sth = $self->prepare(   "update job set stage='".$job->stage."' 
                                    where job_id = ". $job->dbID);
	    $sth->execute();
    };
	
    if ($@) {
	    $self->throw("Error setting stage for job ".$job->dbID);
    } 
}

=head2 get_status

  Title   : get_status
  Usage   : my $status = $job->get_status
  Function: gets the job status
  Returns : status str.
  Args    : 

=cut

sub get_status {
    my ($self,$job) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }

    my $sth;
    eval {	
	    $sth = $self->prepare(   "select status from job 
                                    where job_id = ".$job->dbID);
	    $sth->execute();
    };
	
    if ($@) {
	    $self->throw("Error getting status for job ".$job->dbID);
    } 

    my ($status) = $sth->fetchrow_array();

    $job->status($status);
    
    return $status;
}

=head2 get_stage

  Title   : get_stage
  Usage   : my $stage = $job->get_stage
  Function: gets the job stage
  Returns  : stage str.
  Args    : 

=cut

sub get_stage {
    my ($self,$job,$arg) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }

    my $sth;
    eval {	
	    $sth = $self->prepare(   "select stage from job 
                                    where job_id = ".$job->dbID);
	    $sth->execute();
    };
	
    if ($@) {
	    $self->throw("Error getting stage for job ".$job->dbID);
    } 
    my ($stage) = $sth->fetchrow_array();
    
    $job->stage($stage);
    return $stage;
}


=head2 _make_query_conditional

  Title   : _make_query_conditional 
  Usage   : my $query = $adaptor->_make_query_conditional()
  Function: Utility method for creating the WHERE clause for job table query.
  Returns : String 
  Args    : -dbid  : The job dbid
            -number: Number of jobs to limit for the fetch
            -status: The list of status types (allowed: NEW,FAILED,BATCHED,COMPLETED)
            -stage : The list of stage types (allowed: READING, WRITING,RUNNING)
            -analysis_id: The analysis id of the jobs
            -process_id: The process ids of the jobs

=cut

sub _make_query_conditional {
  my ($self,@args) = @_;
  my ($table,$dbID,$number,$status,$stage,
      $analysis_id,$process_id,$retry_count) = $self->_rearrange([qw(TABLE
                                                      DBID
                                                      NUMBER
                                                      STATUS
                                                      STAGE
                                                      ANALYSIS_ID
                                                      PROCESS_ID
                                                      RETRY_COUNT
                                                        )],@args);
    my $query="";
    if(defined $dbID) {
        $query .= ($table =~/completed_jobs/i) ? "WHERE completed_job_id=$dbID " : " WHERE job_id=$dbID " ;
    }
    if(defined $status){
        if(ref($status) eq "ARRAY"){
            #do for first
            my $st= shift @{$status};
            $VALID_STATUS{$st} || $self->throw("Invalid state $st requested");
            $query .= ($query =~/where/i) ? " AND ((status='$st')" : " WHERE ((status='$st')";

            foreach my $st(@{$status}){
                $VALID_STATUS{$st} || $self->throw("Invalid state $st requested");
                $query .= " OR (status='$st')";
            }
            $query .= " )";
        }
        else {
            $VALID_STATUS{$status} || $self->throw("Invalid state $status requested");
            $query .= ($query =~/where/i) ? " AND ((status='$status')" : " WHERE ((status='$status')";
        }
    }
    if(defined $stage){

        if(ref ($stage) eq "ARRAY"){
          my $st = shift @{$stage};
          $VALID_STAGE{$st} || $self->throw("Invalid stage $st requested");
          $query .= ($query =~/where/i) ? " AND ((stage='$st')" : " WHERE ((stage='$st')";

          foreach my $st(@{$stage}){
              $VALID_STAGE{$st} || $self->throw("Invalid stage $st requested");
              $query .= " OR (status='$st')";
          }
          $query .= " )";
        }
        else {
            $VALID_STAGE{$stage} || $self->throw("Invalid stage $stage requested");
            $query .= ($query =~/where/i) ? " AND ((stage='$stage')" : " WHERE ((stage='$stage')";
        }
    }
    if(defined $analysis_id){
        $query.= ($query=~/where/i) ? " AND (analysis_id='$analysis_id')":" WHERE (analysis_id='$analysis_id')";
    }
    if(defined $process_id){
        $query.= ($query=~/where/i) ? " AND (process_id='$process_id')":" WHERE (process_id='$process_id')";
    }
    if(defined $retry_count){
        $query.= ($query=~/where/i) ? " AND (retry_count<='$retry_count')":" WHERE (retry_count<='$retry_count')";
    }
            
    $query .= defined $number ? " LIMIT $number": "";

    return $query;

}

=head2 get_job_statistics

  Title   : get_job_statistics
  Usage   : my $query = $adaptor->get_job_statistics()
  Function: Used to check state of jobs in the pipeline, returns a hash keyed by status and stage
  Returns : 
  Args    : 

=cut

sub get_job_statistics{
  my ($self) = @_;
  my %job_hash;
  foreach my $status(keys %VALID_STATUS){
    my $total = 0;
    foreach my $stage(keys %VALID_STAGE){
      my $count =  $self->get_job_count(-status=>[$status],-stage=>[$stage]);
      $job_hash{$status}{$stage} = $count;
      $total+=$count; 
    }
    $job_hash{$status}{'TOTAL'} = $total;
  }
  return \%job_hash;
}
  
1;

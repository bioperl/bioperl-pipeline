# BioPerl module for Bio::Pipeline::SQL::JobAdaptor
#
# Adaptred from Arne Stabenau EnsEMBL JobAdaptor
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::JobAdaptor 

=head1 SYNOPSIS

  $jobAdaptor = $dbobj->get_JobAdaptor;
  $jobAdaptor = $jobobj->adaptor;


=head1 DESCRIPTION
  
  Module to encapsulate all db access for persistent class Job.
  There should be just one per application and database connection.
     
=head1 FEEDBACK

=head2 Mailing Lists

=head1 CONTACT


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::Pipeline::SQL::JobAdaptor;

use Bio::Pipeline::Job;
use Bio::Pipeline::SQL::InputAdaptor;
use Bio::Root::Root;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);


=head2 fetch_by_dbID

  Title   : fetch_by_dbID
  Usage   : my $job = $adaptor->fetch_by_dbID
  Function: Retrieves a job from database by internal id
  Returns : throws exception when something goes wrong.
            undef if the id is not in the db.
  Args    : 

=cut

sub fetch_by_dbID {
  my $self = shift;
  my $id = shift;
  my $job;

  my $sth = $self->prepare( q{
   SELECT job_id, process_id, analysis_id, queue_id, object_file,
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
   '-id'       => $hashref->{'job_id'},
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


=head2 fetch_by_analysisId_and_processId_

  Title   : fetch_by_analysisId_and_processId
  Usage   : my $job = $adaptor->fetch_by_analysisId_and_processId
  Function: Retrieves all jobs from database by their analysis_id and processId 
  Returns : throws exception when something goes wrong.
  Args    : analysis_id, process_id 

=cut

sub fetch_by_analysisId_and_processId {
  my $self = shift;
  my $analysis_id = shift;
  my $process_id = shift;
  my @jobs;

 
  my $query = " SELECT job_id
                FROM job
                WHERE analysis_id = $analysis_id and process_id = '$process_id'" ;

  my $sth = $self->prepare($query);
  $sth->execute();

  while (my ($job_id) = $sth->fetchrow_array) {
     my $job = $self->fetch_by_dbID($job_id);
     push (@jobs, $job);
  }
  return @jobs;
}


sub fetch_completed_jobids_by_analysisId_and_processId {
  my $self = shift;
  my $analysis_id = shift;
  my $process_id = shift;
  my @job_ids;


  my $query = " SELECT completed_job_id
                FROM completed_jobs
                WHERE analysis_id = $analysis_id and process_id = '$process_id'" ;

  my $sth = $self->prepare($query);
  $sth->execute();
  
  while (my ($job_id) = $sth->fetchrow_array) {
     push (@job_ids, $job_id);
  }
  return @job_ids;
}

sub fetch_output_ids {
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

    

=head2 fetch_all

  Title   : fetch_all
  Usage   : my @jobs = $adaptor->fetch_all
  Function: Retrieves all the jobs from the database 
  Returns : ARRAY of Bio::Pipeline::Jobs
  Args    : 

=cut

sub fetch_all {
    my ($self,$retry) = @_;

    my @jobs;
    
    my $query = "SELECT job_id FROM job";

    if ($retry) { $query .= " WHERE retry_count < $retry";}

    my $sth = $self->prepare($query);
    $sth->execute;

    while (my ($job_id) = $sth->fetchrow_array){
        my $job = $self->fetch_by_dbID($job_id);
        push (@jobs,$job);
    }

    return @jobs;
}

=head2 job_count

  Title   : job_count
  Usage   : my $count = $adaptor->job_count
  Function: gives a count of the number of jobs that are still incomplete.
  Returns : int 
  Args    : 

=cut

sub job_count{
    my ($self,$retry) = @_;

    my $query = "SELECT count(*) FROM job";

    if ($retry) { $query .= " WHERE retry_count < $retry";}

    my $sth = $self->prepare($query);
    $sth->execute;

    my ($count) = $sth->fetchrow_array;
    return $count;
}

=head2 fetch_new_failed_jobs

  Title   : fetch_new_failed_jobs
  Usage   : my @jobs = $adaptor->fetch_new_failed_jobs
  Function: Retrieves all the jobs from the database 
            that have the status 'NEW' or 'FAILED'
  Returns : ARRAY of Bio::Pipeline::Jobs
  Args    : 

=cut

sub fetch_new_failed_jobs {
    my ($self,$retry) = @_;

    $self->throw ("Need to supply retry count argument") unless $retry;

    my @jobs;
    
    my $query = "   SELECT job_id 
                    FROM job 
                    WHERE (status = 'NEW ') or
                          (status = 'FAILED' and retry_count < $retry)";

    my $sth = $self->prepare($query);
    $sth->execute;

    while (my ($job_id) = $sth->fetchrow_array){
        my $job = $self->fetch_by_dbID($job_id);
        push (@jobs,$job);
    }

    return @jobs;

}


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

  if( ! defined( $job->analysis->dbID )) {
    $self->throw( "Need to store analysis first" );
  }

  my $sth = $self->prepare( q{
    INSERT into job( analysis_id,
      stdout_file, stderr_file, object_file,
      status,time) 
    VALUES ( ?, ?, ?, ?, ?, now() ) } );

  $sth->execute( $job->analysis->dbID,
                 $job->stdout_file,
                 $job->stderr_file,
                 $job->input_object_file,
                 'NEW');

  $sth = $self->prepare( "SELECT LAST_INSERT_ID()" );
  $sth->execute;

  my $dbId = ($sth->fetchrow_arrayref)->[0];
  $job->dbID( $dbId );
  $job->adaptor( $self );

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
       SET stdout_file = ?,
           stderr_file = ?,
           object_file = ?,
           retry_count = ?,
           queue_id = ?,
           stage = ?,
           status = ?,
           process_id = ?
     WHERE job_id = ? } );

  eval {
  $sth->execute( $job->stdout_file,
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

  print "debug2\n";
  $self->throw("Can't update a completed job that has no dbID!") unless (defined $job->dbID);
  
  my $query = " INSERT INTO completed_jobs
                     VALUES (".$job->dbID.",'".
                            $job->process_id."',".
                            $job->analysis->dbID.",".
                            $job->queue_id.",".
                            "'".$job->stdout_file."',".
                            "'".$job->stderr_file."',".
                            "'".$job->input_object_file."',".
                            "now(),".
                            $job->retry_count.")";
  my $sth = $self->prepare($query);

  eval { 
      $sth->execute;
  };if ($@) { $self->throw("ATTEMPT TO UPDATE COMLETED JOB FAILED.\n.$@");}

  return 1;
}

sub exists {
  my $self = shift;
  my $hashref = shift;

  $self->throw( "Not implemented yet" );
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
  Returns : stage str.
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


sub db {
  my ( $self, $arg )  = @_;
  if(  defined $arg ) {
      $self->{'_db'} = $arg;
  }
  $self->{'_db'};
}

sub prepare {
  my ( $self, $query ) = @_;
  $self->db->prepare( $query );
}

sub deleteObj {
  my ($self) = @_;
  my @dummy = values %{$self};
  foreach my $key ( keys %$self ) {
    delete $self->{$key};
  }
  foreach my $obj ( @dummy ) {
    eval {
      $obj->deleteObj;
    }
  }
}

1;

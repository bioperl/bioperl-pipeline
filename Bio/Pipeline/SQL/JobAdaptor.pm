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
   SELECT job_id, analysis_id, queue_id, object_file,
      stdout_file, stderr_file, retry_count
    FROM job
    WHERE job_id = ? } );
  
  $sth->execute( $id );

  my $hashref = $sth->fetchrow_hashref;

  my $analysis = 
    $self->db->get_AnalysisAdaptor->
      fetch_by_dbID( $hashref->{analysis_id} );

  $job = Bio::Pipeline::Job->new
  (
   '-dbobj'    => $self->db,
   '-adaptor'  => $self,
   '-id'       => $hashref->{'job_id'},
   '-lsf_id'   => $hashref->{'queue_id'},
   '-input_id' => $hashref->{'input_id'},
   '-stdout'   => $hashref->{'stdout_file'},
   '-stderr'   => $hashref->{'stderr_file'},
   '-input_object_file' => $hashref->{'object_file'},
   '-analysis' => $analysis,
   '-retry_count' => $hashref->{'retry_count'}
  );

  if( ! defined $hashref ) {
    return undef;
  }

  my $query = "SELECT input_id
               FROM input
               WHERE job_id = $id";
  $sth = $self->prepare($query);
  $sth->execute;
  
  while (my ($input_id) = $sth->fetchrow_array){
      my $input = $self->db->get_InputAdaptor->
                         fetch_by_dbID($input_id);
      $job->add_input($input);                   
  }
  

  return $job;
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
    INSERT into job( input_id, analysis_id,
      queue_id, stdout_file, stderr_file, object_file,
      retry_count ) 
    VALUES ( ?, ?, ?, ?, ?, ?, ?, ? ) } );

  $sth->execute( $job->input_id,
                 $job->analysis->dbID,
                 $job->queue_id,
                 $job->stdout_file,
                 $job->stderr_file,
                 $job->input_object_file,
                 $job->retry_count );

  $sth = $self->prepare( "SELECT LAST_INSERT_ID()" );
  $sth->execute;

  my $dbId = ($sth->fetchrow_arrayref)->[0];
  $job->dbID( $dbId );
  $job->adaptor( $self );

  $self->set_status( $job, "CREATED" );
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

  $sth = $self->prepare( qq{
    DELETE FROM current_status
     WHERE job_id=$dbID } );
  $sth->execute;

  $sth = $self->prepare( qq{
    DELETE FROM jobstatus
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
  $sth->execute;

  $sth = $self->prepare( qq{
    DELETE FROM current_status
     WHERE job_id IN $inExpr } );
  $sth->execute;
  $sth = $self->prepare( qq{
    DELETE FROM jobstatus
     WHERE job_id IN $inExpr } );
  $sth->execute;
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
           queue_id = ?
     WHERE job_id = ? } );

  $sth->execute( $job->stdout_file,
		 $job->stderr_file,
		 $job->input_object_file,
		 $job->retry_count,
		 $job->queue_id,
		 $job->dbID );
}



=head2 _objFromHashref

  Title   : _objFromHashref
  Usage   : my $job = $self->objFromHashref( $queryResult )
  Function: Creates a Job object from given hash reference.
            The hash contains column names and content of the column. 
  Returns : the object or undef if that wasnt possible
  Args    : a hash reference

=cut

sub _objFromHashref {
  # create the appropriate job object

  my $self = shift;
  my $hashref = shift;
  my $job;
  my $analysis;

  $analysis = 
    $self->db->get_AnalysisAdaptor->
      fetch_by_dbID( $hashref->{analysis_id} );

  $job = Bio::Pipeline::Job->new
  (
   '-dbobj'    => $self->db,
   '-adaptor'  => $self,
   '-id'       => $hashref->{'job_id'},
   '-lsf_id'   => $hashref->{'queue_id'},
   '-input_id' => $hashref->{'input_id'},
   '-stdout'   => $hashref->{'stdout_file'},
   '-stderr'   => $hashref->{'stderr_file'},
   '-input_object_file' => $hashref->{'object_file'},
   '-analysis' => $analysis,
   '-retry_count' => $hashref->{'retry_count'}
  );

  return $job;
}


# provide a hashref
# each value in it used for a combined query, if the described object is in
# returns a job object, if it is in, else undef

sub exists {
  my $self = shift;
  my $hashref = shift;

  $self->throw( "Not implemented yet" );
}

# Code directly from Michele

=head2 set_status

  Title   : set_status
  Usage   : my $status = $job->set_status
  Function: Sets the job status
  Returns : nothing
  Args    : Pipeline::Job Bio::Pipeline::Status

=cut

sub set_status {
    my ($self,$job,$arg) = @_;

    if( ! defined $job->dbID ) {
      $self->throw( "Job has to be in database" );
    }

    my $status;

    eval {	
	my $sth = $self->prepare("insert delayed into jobstatus(job_id,status,time) values (" .
					 $job->dbID . ",\"" .
					 $arg      . "\"," .
					 "now())");
	my $res = $sth->execute();

	$sth = $self->prepare("replace into current_status(job_id,status) values (" .
				      $job->dbID . ",\"" .
				      $arg      . "\")");

	$res = $sth->execute();
	
	$sth = $self->prepare("select now()" );
	
	$res = $sth->execute();
	
	my $rowhash = $sth->fetchrow_arrayref();
	my $time    = $rowhash->[0];

	$status = Bio::Pipeline::Status->new
	  (  '-jobid'   => $job->dbID,
	     '-status'  => $arg,
	     '-created' => $time,
	  );
	
	$self->current_status($job, $status);
	
#	print("Status for job [" . $job->dbID . "] set to " . $status->status . "\n");
    };

    if ($@) {
#      print( " $@ " );

	$self->throw("Error setting status to $arg");
    } else {
	return $status;
    }
}


=head2 current_status

  Title   : current_status
  Usage   : my $status = $job->current_status
  Function: Get/set method for the current status
  Returns : Bio::Pipeline::Status
  Args    : Bio::Pipeline::Status

=cut

sub current_status {
    my ($self, $job, $arg) = @_;

    if (defined($arg)) 
    {
	$self->throw("[$arg] is not a Bio::Pipeline::Status object") 
	    unless $arg->isa("Bio::Pipeline::Status");
	$job->{'_status'} = $arg;
    }
    else 
    {
	$self->throw("Can't get status if id not defined") 
	    unless defined($job->dbID);
	my $id =$job->dbID;
	my $sth = $self->prepare
	    ("select status from current_status where job_id=$id");
	my $res = $sth->execute();
	my $status;
	while (my  $rowhash = $sth->fetchrow_hashref() ) {
	    $status = $rowhash->{'status'};
	}

	$sth = $self->prepare("select now()");
	$res = $sth->execute();
	my $time;
	while (my  $rowhash = $sth->fetchrow_hashref() ) {
	    $time    = $rowhash->{'now()'};
	}
	my $statusobj = new Bio::Pipeline::Status
	    ('-jobid'   => $id,
	     '-status'  => $status,
	     '-created' => $time,
	     );
	$job->{'_status'} = $statusobj;
    }
    return $job->{'_status'};
}

=head2 get_all_status

  Title   : get_all_status
  Usage   : my @status = $job->get_all_status
 Function: Get all status objects associated with this job
  Returns : @Bio::Pipeline::Status
  Args    : Bio::Pipeline::Job

=cut

sub get_all_status {
  my ($self, $job) = @_;
  
  $self->throw("Can't get status if id not defined") 
    unless defined($job->dbID);

  my $sth = $self->prepare
    ("select job_id,status, UNIX_TIMESTAMP(time) from  jobstatus " . 
     "where id = \"" . $job->dbID . "\" order by time desc");
  
  my $res = $sth->execute();
  
  my @status;
  while (my $rowhash = $sth->fetchrow_hashref() ) {
    my $time      = $rowhash->{'UNIX_TIMESTAMP(time)'};#$rowhash->{'time'};
    my $status    = $rowhash->{'status'};
    my $statusobj = new Bio::Pipeline::Status(-jobid   => $job->dbID,
						       -status  => $status,
						       -created => $time,
						      );
                               
    push(@status,$statusobj);
    
  }
  
  return @status;
}

=head2 get_last_status

  Title   : get_last_status
  Usage   : my @status = $job->get_all_status
  Function: Get most recent status object associated with this job
  Returns : Bio::Pipeline::Status
  Args    : Bio::Pipeline::Job, status string

=cut

sub get_last_status {
  my ($self, $job) = @_;

  $self->throw("Can't get status if id not defined")
    unless defined($job->dbID);

  my $sth = $self->prepare (qq{
    SELECT js.job_id, cs.status, UNIX_TIMESTAMP(time)
      FROM jobstatus js, current_status cs
     WHERE js.job_id = cs.job_id
       AND js.status = cs.status
       AND js.job_id = ?} );

  my $res = $sth->execute($job->dbID);
  my $rowHashRef = $sth->fetchrow_hashref();
  if( ! defined $rowHashRef ) {
    return undef;
  }

  my $time      = $rowHashRef->{'UNIX_TIMESTAMP(time)'};#$rowhash->{'time'};
  my $status    = $rowHashRef->{'status'};
  my $statusobj = new Bio::Pipeline::Status(-jobid   => $job->dbID,
						     -status  => $status,
						     -created => $time,
						     );
  return $statusobj;
}

sub list_job_id_by_status {
  my ($self,$status) = @_;
  my @result;
  my @row;

  my $sth = $self->prepare( qq{
    SELECT j.job_id
      FROM job j, current_status c
     WHERE j.job_id = c.job_id
       AND c.status = '$status'
     ORDER BY job_id } );
  $sth->execute;
  
  while( @row = $sth->fetchrow_array ) {
    push( @result, $row[0] );
  }
  
  return @result;
}


sub list_job_id_by_status_age {
  my ($self,$status,$age) = @_;
  
  my @result;
  my @row;
  my $sth = $self->prepare( qq{
    SELECT js.job_id
      FROM current_status c, jobstatus js
     WHERE js.job_id = c.job_id
       AND c.status = '$status'
       AND js.status = '$status'
       AND js.time < DATE_SUB( NOW(), INTERVAL $age MINUTE )
     ORDER BY job_id } );
  $sth->execute;
  
  while( @row = $sth->fetchrow_array ) {
    push( @result, $row[0] );
  }
  
  return @result;
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

# creates all tables for this adaptor - job, jobstatus and current_status
# if they exist they are emptied and newly created
sub create_tables {
  my $self = shift;
  my $sth;

  $sth = $self->prepare("drop table if exists job");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE job (
    job_id        int(10) unsigned  default 0  not null auto_increment,
    input_id      varchar(40)       default '' not null,
    analysis_id   int(10) unsigned  default 0  not null,
    queue_id        int(10) unsigned  default 0,
    stdout_file   varchar(100)      default '' not null,
    stderr_file   varchar(100)      default '' not null,
    object_file   varchar(100)      default '' not null,
    retry_count   int               default 0,

    PRIMARY KEY   (job_id),
    KEY input     (input_id),
    KEY analysis  (analysis_id)
    );
  });
  $sth->execute();

  $sth = $self->prepare("drop table if exists jobstatus");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE jobstatus (
    job_id     int(10) unsigned  default 0 not null,
    status     varchar(40)       default 'CREATED' not null,
    time       datetime          default '0000-00-00 00:00:00' not null,

    KEY job    (job_id),
    KEY status (status)
    );
  });
  $sth->execute();

  $sth = $self->prepare("drop table if exists current_status");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE current_status (
    job_id  int(10) unsigned  default 0 not null,
    status  varchar(40)       default '' not null,

    PRIMARY KEY (job_id),
    KEY status  (status)
    );
  });
  $sth->execute();
  $sth->finish;
}

1;

# BioPerl module for Bio::Pipeline::Job
#
# Adapted from Michele Clamp's EnsEMBL::Job.pm
# 
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::Job

=head1 SYNOPSIS

=head1 DESCRIPTION

Stores run and status details of an analysis job

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Job;

use Bio::Pipeline::Analysis;
use Bio::Pipeline::Status;
use Bio::Pipeline::SQL::JobAdaptor;

# several variables needed from PipeConf.pm
use Bio::Pipeline::PipeConf qw ( RUNNER 
                                 NFSTMP_DIR
                               );

use vars qw(@ISA);
use strict;


# Object preamble - inherits from Bio::Root::Object;
@ISA = qw(Bio::Root::RootI);

# following vars are static and not meaningful on remote side
# recreation of Job object. Not stored in db of course.
# hash with queue keys

my %batched_jobs;
my %batched_jobs_runtime;

sub new {
    my ($class, @args) = @_;
    my $self = bless {},$class;

    my ($adaptor,$dbID,$queueid,$input_id,$analysis,$stdout,$stderr,$input, $retry_count ) 
	= $self->_rearrange([qw(ADAPTOR
				ID
				QUEUE_ID
				INPUT_ID
				ANALYSIS
				STDOUT
				STDERR
				INPUT_OBJECT_FILE
				RETRY_COUNT
				)],@args);

				
    $dbID    = -1 unless defined($dbID);
    $queueid = -1 unless defined($queueid);
    $cls = 'contig' unless defined($cls);

    $input_id   || $self->throw("Can't create a job object without an input_id");
    $analysis   || $self->throw("Can't create a job object without an analysis object");

    $analysis->isa("Bio::Pipeline::Analysis") ||
	$self->throw("Analysis object [$analysis] is not a Bio::Pipeline::Analysis");

    $self->dbID         ($dbID);
    $self->adaptor  ($adaptor);
    $self->input_id   ($input_id);
    $self->analysis   ($analysis);
    $self->stdout_file($stdout);
    $self->stderr_file($stderr);
    $self->input_object_file($input);
    $self->retry_count( $retry_count );
    $self->QUEUE_id( $queueid );

    return $self;
}


=head2 create_by_analysis_inputId

  Title   : create_by_analysis_inputId
  Usage   : $class->create_by.....
  Function: Creates a job given an analysis object and an inputId
            Recommended way of creating job objects!
  Returns : a job object, not connected to db
  Args    : 

=cut

sub create_by_analysis_inputId {
  my $dummy = shift;
  my $analysis = shift;
  my $inputId = shift;

  my $job = Bio::Pipeline::Job->new
    ( -input_id    => $inputId,
      -analysis    => $analysis,
      -retry_count => 0,
    );
  $job->make_filenames;
  return $job;
}



=head2 dbID

  Title   : dbID
  Usage   : $self->dbID($id)
  Function: get set the dbID for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut


sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_dbID'} = $arg;
    }
    return $self->{'_dbID'};

}

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor
  Function: get database adaptor, set only for constructor and adaptor usage. 
  Returns : 
  Args    : 

=cut


sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_adaptor'} = $arg;
    }
    return $self->{'_adaptor'};

}



=head2 input_id

  Title   : input_id
  Usage   : $self->input_id($id)
  Function: Get/set method for the id of the input to the job
  Returns : string
  Args    : string

=cut


sub input_id {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_input_id'} = $arg;
    }
    return $self->{'_input_id'};
}

=head2 analysis

  Title   : analysis
  Usage   : $self->analysis($anal);
  Function: Get/set method for the analysis object of the job
  Returns : Bio::Pipeline::Analysis
  Args    : Bio::Pipeline::Analysis

=cut

sub analysis {
    my ($self,$arg) = @_;
    if (defined($arg)) {
	$self->throw("[$arg] is not a Bio::Pipeline::Analysis object" ) 
            unless $arg->isa("Bio::Pipeline::Analysis");

	$self->{'_analysis'} = $arg;
    }
    return $self->{'_analysis'};

}


=head2 flush_runs

  Title   : flush_runs
  Usage   : $job->flush_runs( jobadaptor, [queue] );
  Function: Issue all jobs in the queue and empty the queue.
    Set QUEUE id in all jobs. Uses the given adaptor for connecting to
    db. Uses last job in queue for stdout/stderr. 
  Returns : 
  Args    : 

=cut

sub flush_runs {
  my $self = shift;

  my $adaptor = shift;
  my $QUEUE_params = shift;
  my @queues;
  
  my $nodes   = $QUEUE_params->{'nodes'}   || undef;
  my $queue   = $QUEUE_params->{'queue'}   || undef;
  my $jobname = $QUEUE_params->{'jobname'} || undef;

  if( !defined $adaptor ) {
    $self->throw( "Cannot run remote without db connection" );
  }

  local *SUB;
  local *FILE;

  if( ! defined $queue ) {
    @queues = keys %batched_jobs;
  } else {
    @queues = ( $queue );
  }
  
  my $db       = $adaptor->db;
  my $host     = $db->host;
  my $username = $db->username;
  my $dbname   = $db->dbname;
  my $pass     = $db->password;
  my $queueid;

  # runner.pl: first look in PipeConf.pm,
  # then in same directory as Job.pm,
  # and fail if not found

  my $runner = $RUNNER || undef;

  unless (-x $runner) {
    $runner = __FILE__;
    $runner =~ s:/[^/]*$:/runner.pl:;
    $self->throw("runner undefined - needs to be set in PipeConf.pm\n") unless defined $runner;
  }

  for my $queue ( @queues ) {

    if (! (defined $batched_jobs{$queue}) || ! scalar (@{$batched_jobs{$queue}})) {
      next;
    }

    my $lastjob = $adaptor->fetch_by_dbID( $batched_jobs{$queue}->[$#{$batched_jobs{$queue}}] );

    if( ! defined $lastjob ) {
      $self->throw( "Last batch job not in db" );
    }
  
    my $cmd;
  
    $cmd = "bsub -o ".$lastjob->stdout_file;
    if ($nodes) {
	# $nodes needs to be a space-delimited list
	$nodes =~ s/,/ /;
	$nodes =~ s/ +/ /;
	# undef $nodes unless $nodes =~ m{(\w+\ )*\w};
        $cmd .= " -m '$nodes' ";
    }
    $cmd .= " -q $queue " if defined $queue;
    $cmd .= " -J $jobname " if defined $jobname;
    $cmd .= " -r -e ".$lastjob->stderr_file." -E \"$runner -check\" ";

    # check if the password has been defined, and write the
    # "connect" command line accordingly (otherwise -pass gets the
    # first job id as password, instead of remaining undef)

    if ($pass) {
      $cmd .= $runner." -host $host -dbuser $username -dbname $dbname -pass $pass ".join( " ",@{$batched_jobs{$queue}} );
    }
    else {
      $cmd .= $runner." -host $host -dbuser $username -dbname $dbname ".join( " ",@{$batched_jobs{$queue}} );
    }
    
    print STDERR "$cmd\n";
    open (SUB,"$cmd 2>&1 |");
  
    while (<SUB>) {
      if (/Job <(\d+)>/) {
        $queueid = $1;
      }
    }
    close(SUB);

    if( ! defined $queueid ) {
      print STDERR ( "Couldnt submit ".join( " ",@{$batched_jobs{$queue}} )." to QUEUE" );
      foreach my $jobid ( @{$batched_jobs{$queue}} ) {
        my $job = $adaptor->fetch_by_dbID( $jobid );
        $job->set_status( "FAILED" );
      }
    } else {
    
      foreach my $jobid ( @{$batched_jobs{$queue}} ) {
        my $job = $adaptor->fetch_by_dbID( $jobid );
        if( $job->retry_count > 0 ) {
          for ( $job->stdout_file, $job->stderr_file ) {
            open( FILE, ">".$_ ); close( FILE );
          }
        }
	$job->QUEUE_id( $queueid );
        # $job->create_queuelogfile;
        $job->retry_count( $job->retry_count + 1 );
        $job->set_status( "SUBMITTED" );
        $adaptor->update( $job );
      }
    }
    $batched_jobs{$queue} = [];
    $batched_jobs_runtime{$queue} = 0;
  }
}


=head2 batch_runRemote

  Title   : batch_runRemote
  Usage   : $job->batch_runRemote
  Function: Issue more than one small job in one QUEUE job because 
    job submission is very slow
  Returns : 
  Args    : Is static, private function, dont call with arrow notation.

=cut

sub batch_runRemote {
  my $self = shift;
  my $QUEUE_params = shift;

  my $batchsize = $QUEUE_params->{'flushsize'} || 1;
  my $queue     = $QUEUE_params->{'queue'};
  
  # should check job->analysis->runtime
  # and add it to batched_jobs_runtime
  # but for now just
  push( @{$batched_jobs{$queue}}, $self->dbID );
  if ( scalar( @{$batched_jobs{$queue}} ) >= $batchsize ) {
    $self->flush_runs( $self->adaptor, $QUEUE_params );
  }
}





=head2 runLocally
=head2 runRemote( boolean withDB, queue )
=head2 runInQUEUE

  Title   : running
  Usage   : $self->run...;
  Function: runLocally doesnt submit to QUEUE
            runInQUEUE is like runLocally, but doesnt redirect STDOUT and 
            STDERR. 
            runRemote submits to QUEUE via the runner.pl script.
  Returns : 
  Args    : 

=cut

sub runLocally {
  print STDERR "Running locally\n"; 
  my $self = shift;

  print STDERR "Running locally " . $self->stdout_file . " " . $self->stderr_file . "\n"; 

  local *STDOUT;
  local *STDERR;

  if( ! open ( STDOUT, ">".$self->stdout_file )) {
    $self->set_status( "FAILED" );
    return;
  }
        
  if( ! open ( STDERR, ">".$self->stderr_file )) {
    $self->set_status( "FAILED" );
    return;
  }
       print STDERR "Running inQUEUE\n"; 
  $self->runInQUEUE();
}

sub run_BatchRemote{
  my $self = shift;
  my $queue = shift;
  my $useDB = shift;

  local *SUB;
  local *FILE;

  if( !defined $self->adaptor ) {
    $self->throw( "Cannot run remote without db connection" );
  }

  my $db = $self->adaptor->db;
  my $host = $db->host;
  my $username = $db->username;
  my $dbname = $db->dbname;
  my $cmd;

  # runner.pl: first look in same directory as Job.pm
  # if it's not here use file defined in PipeConf.pm
  # otherwise fail

  my $runner = __FILE__;
  $runner =~ s:/[^/]*$:/runner.pl:; 	

  unless (-x $runner) {
    $runner = $RUNNER || undef;
    $self->throw("runner undefined - needs to be set in PipeConf.pm\n") unless defined $runner;
  }

  $cmd = "bsub -q ".$queue." -o ".$self->stdout_file.
#    " -q acarichunky " .
#    " -R osf1 ".
    " -e ".$self->stderr_file." -E \"$runner -check\" ";


  if( ! defined $useDB ) {
    $useDB = 1;
  }

  if( $self->retry_count > 0 ) {
    for ( $self->stdout_file, $self->stderr_file ) {
      open( FILE, ">".$_ ); close( FILE );
    }
  }

  if( $useDB ) {
    # find out db details from adaptor
    # generate the queue call
    $cmd .= $runner." -host $host -dbuser $username -dbname $dbname ".$self->dbID;
    
  } else {
    # make the object
    # call its get input method..
    # freeze it
    $self->throw( "useDB=0 not implemented yet." );
  }
  print STDERR "$cmd\n";
  open (SUB,"$cmd 2>&1 |");
  
  while (<SUB>) {
    if (/Job <(\d+)>/) {
      $self->QUEUE_id($1);
      # print (STDERR $_);
    }
  }
  close(SUB);

  if( $self->QUEUE_id == -1 ) {
    print STDERR ( "Couldnt submit ".$self->dbID." to QUEUE" );
  } else {
    $self->retry_count( $self->retry_count + 1 );
    $self->set_status( "SUBMITTED" );
  }

  $self->adaptor->update( $self );
}

# question, when to submit the success report to the db?
# we have to parse the output of QUEUE anyway....
sub runInQUEUE {
  my $self = shift;
  my $module = $self->analysis->module;
  my $rdb;
  my $err;
  my $autoupdate = $AUTOUPDATE;
  

  eval {
      if( $module =~ /::/ ) {
	  $module =~ s/::/\//g;
	  require "${module}.pm";
	  $rdb = "${module}"->new
	      ( -analysis => $self->analysis,
		-input_id => $self->input_id,
		-dbobj => $self->adaptor->db );
      } else {
	      ####BUFF!!!!!########
	  require "Bio/Pipeline/RunnableDB/${module}.pm";
          $module =~ s/\//::/g;
	  $rdb = "Bio::EnsEMBL::Pipeline::RunnableDB::${module}"->new
	      ( -analysis => $self->analysis,
		-input_id => $self->input_id,
		-dbobj => $self->adaptor->db );
      }
  };
  if ($err = $@) {
      print (STDERR "CREATE: Lost the will to live Error\n");
      $self->set_status( "FAILED" );
      $self->throw( "Problems creating runnable $module for " . $self->input_id . " [$err]\n");
  }
  eval {   
      $self->set_status( "READING" );
      $rdb->fetch_input;
  };
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "READING: Lost the will to live Error\n");
      die "Problems with $module fetching input for " . $self->input_id . " [$err]\n";
  }
  if ($rdb->input_is_void) {
      $self->set_status( "VOID" );
      return;
  }
  eval {
      $self->set_status( "RUNNING" );
      $rdb->run;
  };
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "RUNNING: Lost the will to live Error\n");
      die "Problems running $module for " . $self->input_id . " [$err]\n";
  }
  eval {
      $self->set_status( "WRITING" );
      $rdb->write_output;
      $self->set_status( "SUCCESSFUL" );
  }; 
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "WRITING: Lost the will to live Error\n");
      die "Problems for $module writing output for " . $self->input_id . " [$err]" ;
  }
  if ($autoupdate) {
    eval {
      my $sic = $self->adaptor->db->get_StateInfoContainer;
      $sic->store_inputId_analysis(
        $self->input_id,
        $self->analysis
      );
    };
    if ($err = $@) {
      print STDERR "Error updating successful job ".$self->dbID ."[$err]\n";
    }
    else {
      print STDERR "Updated successful job ".$self->dbID."\n";
      eval {
        $self->remove;
      };
      if ($err = $@) {
         print STDERR "Error deleting job ".$self->dbID." [$err]\n";
      }
      else {
         print STDERR "Deleted job ".$self->dbID."\n";
      }
    }
  }
}


=head2 resultToDb

  Title   : resultToDB
  Usage   : $self->resultToDb;
  Function: Find if job finished by looking at STDOUT and STDERR
            try set current_status according to what you find.
            write_output on the runnablDB is recommended way of 
            putting results into the DB.
            DONT use when job started with db connection.
  Returns : false, if job seems not to be finished on the remote side..
  Args    : 

=cut

sub resultToDb {
  my $self = shift;
  $self->throw( "Not implemented yet." );
}


sub write_object_file {
    my ($self,$arg) = @_;

    $self->throw("No input object file defined") unless defined($self->input_object_file);

    if (defined($arg)) {
	my $str = FreezeThaw::freeze($arg);
	open(OUT,">" . $self->input_object_file) || $self->throw("Couldn't open object file " . $self->input_object_file);
	print(OUT $str);
	close(OUT);
    }
}


=head2 set_status

  Title   : set_status
  Usage   : my $status = $job->set_status
  Function: Sets the job status
  Returns : nothing
  Args    : Bio::Pipeline::Status

=cut

sub set_status {
  my ($self,$arg) = @_;
  
  $self->throw("No status input" ) unless defined($arg);
  
  
  if (!(defined($self->adaptor))) {
    $self->warn("No database connection.  Can't set status to $arg");
    return;
  }
  
  return $self->adaptor->set_status( $self, $arg );
}


=head2 current_status

  Title   : current_status
  Usage   : my $status = $job->current_status
  Function: Get/set method for the current status
  Returns : Bio::Pipeline::Status
  Args    : Bio::Pipeline::Status

=cut

sub current_status {
  my ($self,$arg) = @_;
  
  if( ! defined( $self->adaptor )) {
    return undef;
  }
 
  return $self->adaptor->current_status( $self, $arg );
}

=head2 get_all_status

  Title   : get_all_status
  Usage   : my @status = $job->get_all_status
  Function: Get all status objects associated with this job
  Returns : @Bio::Pipeline::Status
  Args    : @Bio::Pipeline::Status

=cut

sub get_all_status {
  my ($self) = @_;
  
  if( $self->adaptor ) {
    return $self->adaptor->get_all_status( $self );
  } else {
    return undef;
  }
}


=head2 get_last_status

  Title   : get_last_status
  Usage   : my @status = $job->get_all_status ($status)
  Function: Get latest status object associated with this job
  Returns : Bio::Pipeline::Status
  Args    : status string

=cut

sub get_last_status {
  my ($self) = @_;
  
  if( $self->adaptor ) {
    return $self->adaptor->get_last_status( $self );
  } else {
    return undef;
  }
}


sub make_filenames {
  my ($self) = @_;
  
  my $num = int(rand(10));
  my $dir = $NFSTMP_DIR . "/$num/";
  if( ! -e $dir ) {
    system( "mkdir $dir" );
  }

# scp - one set of out files per job (even if batching together)
# this is a bit messy! added '.0' to $stub. This will be the master
# file containing QUEUE output. In runner.pl before each job is run
# replace 0 with the job ID to get one output file per $job.
# Change also Job::remove to do a glob on all these files. Yep it's
# nasty but it seems to work...


  my $stub = $self->input_id.".";
  $stub .= $self->analysis->logic_name.".";
  $stub .= time().".".int(rand(1000));
#   $stub .= time().".".int(rand(1000)) . '.0';

#  my @files = $self->get_files( $self->input_id,"obj","out","err" );
#  for (@files) {
#    open( FILE, ">".$_ ); close( FILE );
#  }
 
  $self->input_object_file($dir.$stub.".obj");
  $self->stdout_file($dir.$stub.".out");
  $self->stderr_file($dir.$stub.".err");
}


sub create_queuelogfile {
  my ($self) = @_;
  
  my $num = int(rand(10));
  my $dir = $NFSTMP_DIR . "/$num/";
  if( ! -e $dir ) {
    system( "mkdir $dir" );
  }

  my $stub = $self->QUEUE_id.".";
  $stub .= time().".".int(rand(1000));

  $self->QUEUE_out($dir.$stub.".out");
  $self->QUEUE_err($dir.$stub.".err");
}


sub get_files {
  my ($self,$stub,@exts) = @_;
  my @result;
  my @files;
  my $dir;

  my $count = 0;

  while( 1 ) {
    my $num = int(rand(10));
    $dir = $NFSTMP_DIR . "/$num/";
    if( ! -e $dir ) {
      system( "mkdir $dir" );
    }
    opendir( DIR, $dir );
    @files = readdir( DIR );
    if( scalar( @files ) > 10000 ) {
      if( $count++ > 10 ) {
	$self->throw("10000 files in directory. Can't make a new file");
      } else {
	next;
      }
    } else {
      last;
    }
  }
  $count = 0;
  # Should check disk space here.
  
 OCCU: while( $count++ < 10 ) { 
    my $rand  = int(rand(100000));
    @result = ();
    foreach my $ext ( @exts ) {
      my $file  = $dir . $stub . "." . $rand . "." . $ext;
      if( -e $file ) {
	next OCCU;
      }
      push( @result, $file );
    }
    last;
  }

  if( $count > 9 ) {
    $self->throw( "File generation problem in $dir" );
  }
  return @result;
}



=head2 stdout_file

  Title   : stdout_file
  Usage   : my $file = $self->stdout_file
  Function: Get/set method for stdout.
  Returns : string
  Args    : string

=cut

sub stdout_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_stdout_file'} = $arg;
    }
    return $self->{'_stdout_file'};
}

=head2 stderr_file

  Title   : stderr_file
  Usage   : my $file = $self->stderr_file
  Function: Get/set method for stderr.
  Returns : string
  Args    : string

=cut

sub stderr_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_stderr_file'} = $arg;
    }
    return $self->{'_stderr_file'};
}

=head2 input_object_file

  Title   : input_object_file
  Usage   : my $file = $self->input_object_file
  Function: Get/set method for the input object file
  Returns : string
  Args    : string

=cut

sub input_object_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{'_input_object_file'} = $arg;
    }
    return $self->{'_input_object_file'};
}

=head2 QUEUE_id

  Title   : QUEUE_id
  Usage   : 
  Function: Get/set method for the QUEUE_id
  Returns : 
  Args    : 

=cut

sub QUEUE_id {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_queueid'} = $arg );
  $self->{'_queueid'};
}

sub QUEUE_out {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_queueout'} = $arg );
  $self->{'_queueout'};
}

sub QUEUE_err {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_queueerr'} = $arg );
  $self->{'_queueerr'};
}

=head2 retry_count

  Title   : retry_count
  Usage   : 
  Function: Get/set method for the retry_count
  Returns : 
  Args    : 

=cut

sub retry_count {
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_retry_count'} = $arg );
  $self->{'_retry_count'};
}

sub remove {
  my $self = shift;
  
  if( -e $self->stdout_file ) { unlink( $self->stdout_file ) };
  if( -e $self->stderr_file ) { unlink( $self->stderr_file ) };
  if( -e $self->input_object_file ) { unlink( $self->input_object_file ) };

   if( defined $self->adaptor ) {
   $self->adaptor->remove( $self );
   }
}


=head2 output_file

  Title   : output_file
  Usage   : my $file = $self->output_file
  Function: Get/set method for output
  Returns : string
  Args    : string

=cut

sub output_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_output_file} = $arg;
    }
    return $self->{_output_file};
}


=head2 input_object_file

  Title   : intput_object_file
  Usage   : my $file = $self->input_object_file
  Function: Get/set method for the input object file
  Returns : string
  Args    : string

=cut

sub input_object_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_input_object_file} = $arg;
    }
    return $self->{_input_object_file};
}

=head2 status_file

  Title   : status_file
  Usage   : my $file = $self->status_file
  Function: Get/set method for the status file
  Returns : string
  Args    : string

=cut

sub status_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{_status_file} = $arg;
    }
    return $self->{_status_file};
}

1;
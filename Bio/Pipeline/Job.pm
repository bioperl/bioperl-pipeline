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
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::RunnableDB;

# several variables needed from PipeConf.pm
use Bio::Pipeline::PipeConf qw ( RUNNER 
                                 NFSTMP_DIR
                               );

use vars qw(@ISA);
use strict;


# Object preamble - inherits from Bio::Root::Object;
@ISA = qw(Bio::Root::Root);

# following vars are static and not meaningful on remote side
# recreation of Job object. Not stored in db of course.
# hash with queue keys

my %batched_jobs;
my %batched_jobs_runtime;

sub new {
    my ($class, @args) = @_;
    my $self = bless {},$class;

    my ($adaptor,$dbID,$process_id, $queueid,$inputs,$analysis,$stdout,$stderr,$obj_file, $retry_count,$status,$stage,$output_ids,$dependency ) 
	= $self->_rearrange([qw(ADAPTOR
            				ID
                    PROCESS_ID
			            	QUEUE_ID
			            	INPUTS
			            	ANALYSIS
			            	STDOUT
		            		STDERR
	            			INPUT_OBJECT_FILE
            				RETRY_COUNT
            				STATUS
            				STAGE
                    OUTPUT_IDS
		        	      DEPENDENCY
              )],@args);

				
    $dbID    = undef unless defined($dbID);
    $queueid = 0 unless defined($queueid);

    $analysis   || $self->throw("Can't create a job object without an analysis object");
    $analysis->isa("Bio::Pipeline::Analysis") ||
	  $self->throw("Analysis object [$analysis] is not a Bio::Pipeline::Analysis");

    $self->dbID             ($dbID);
    $self->process_id       ($process_id);
    $self->adaptor          ($adaptor);
    $self->analysis         ($analysis);
    $self->stdout_file      ($stdout);
    $self->stderr_file      ($stderr);
    $self->input_object_file($obj_file);
    $self->retry_count      ($retry_count);
    $self->queue_id         ($queueid);
    $self->status           ($status);
    $self->stage            ($stage);
    #$self->output_ids       ($output_ids);
    $self->dependency($dependency);
    @{$self->{'_inputs'}}= ();
    @{$self->{'_output_ids'}}= ();
    
    
    foreach my $input (@{$inputs}){
        $self->add_input($input);
    }
    
    foreach my $output_id (@{$output_ids}){
       push (@{$self->{'_output_ids'}},$output_id);
    }
    $self->make_filenames unless $self->filenames;

    return $self;
}

sub output_ids {

    my ($self) = @_;
    return @{$self->{'_output_ids'}};
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

  my $job = Bio::Pipeline::Job->new
    ( -analysis    => $analysis,
      -retry_count => 0,
    );
  $job->make_filenames;
  return $job;
}


=head2 create_next_job

  Title   : create_next_job
  Usage   : $class->create_.....
  Function: Creates a job given an analysis object and the previous job
  Returns : a job object, not connected to db
  Args    : 

=cut

sub create_next_job{
  my $self = shift;
  my $next_analysis = shift;
  #my $process_id = shift;

  #my $next_analysis = $self->adaptor->get_AnalysisAdaptor->fetch_by_dbId($next_analysis_id);
  my $new_job = Bio::Pipeline::Job->new
    ( -analysis    => $next_analysis,
      -process_id  => $self->process_id,
      -retry_count => 0,
      -adaptor => $self->adaptor
    );


  $self->adaptor->store($new_job);
  $new_job->make_filenames;

  return $new_job;
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

=head2 process_id

  Title   : process_id
  Usage   : $self->process_id($id)
  Function: get set the process_id for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut


sub process_id {
    my ($self,$arg) = @_;

    if (defined($arg)) {
            $self->{'_process_id'} = $arg;
    }
    return $self->{'_process_id'};

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


=head2 add_input

  Title   : add_input
  Usage   : 
  Function: 
  Returns : 
  Args    : 

=cut

sub add_input {
    my ($self,$input) = @_;

    $input || $self->throw('trying to add input to Job without supplying argument');

    push (@{$self->{'_inputs'}},$input);
}


=head2 inputs

  Title   : inputs
  Usage   : 
  Function: 
  Returns : 
  Args    : 

=cut

sub inputs {
    my ($self) = @_;

    return @{$self->{'_inputs'}};
}

=head2 flush_inputs

  Title   : flush_inputs
  Usage   : $self->flush_inputs
  Function: empty the input array
  Returns : 
  Args    :

=cut

sub flush_inputs {
    my ($self) = @_;

    $self->{'_inputs'} = ();
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

sub dependency {
    my ($self,$arg) = @_;
    if (defined($arg)) {

    $self->{'_dependency'} = $arg;
    }
    return $self->{'_dependency'};

}
##########
=head2 run

  Title   : run
  Usage   : $self->run...;
  Function: 
  Returns : 
  Args    : 

=cut

sub run {

  my $self = shift;
  my $err;
  my $rdb;
  $self->make_filenames unless $self->filenames;
  my @inputs = $self->inputs;

  print STDERR "Running job " . $self->stdout_file . " " . $self->stderr_file . "\n"; 

  local *STDOUT;
  local *STDERR;
  if( ! open ( STDOUT, ">".$self->stdout_file )) {
  print STDERR $self->stdout_file;
    $self->set_status( "FAILED" );
	$self->throw("Cannot pipe STDOUT to stdout_file.");
  }
        
  if( ! open ( STDERR, ">".$self->stderr_file )) {
    $self->set_status( "FAILED" );
	$self->throw("Cannot pipe STDERR to stderr_file.");
  }
  if( !defined $self->adaptor ) {
    $self->throw( "Cannot run remote without db connection" );
  }
 
  eval {
    $rdb = Bio::Pipeline::RunnableDB->new ( 
                        -analysis   => $self->analysis,
                        -inputs     => \@inputs,
                        );
  };                      
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "CREATE: Lost the will to live Error. Problems creating runnabledb \n[$err]\n");
      $self->throw( "Problems creating runnabledb \n[$err]\n");
  }
  eval {   
      $self->set_stage( "READING" );
      $rdb->fetch_input;
  };
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "READING: Lost the will to live Error. Problems with runnableDB fetching input \n[$err]\n");
      $self->throw ("Problems with runnableDB fetching input\n[$err]\n");
  }
  if ($rdb->input_is_void) {
      $self->set_status( "VOID" );
      return;
  }
  eval {
      $self->set_stage( "RUNNING" );
      $rdb->run;
  };
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "RUNNING: Lost the will to live Error. Problems running runnableDB\n[$err]\n");
      $self->throw ("Problems running runnableDB for\n[$err]\n")
  }
  my @output_ids;
  eval {
      $self->set_stage( "WRITING" );
      @output_ids = $rdb->write_output;
  }; 
  if ($err = $@) {
      $self->set_status( "FAILED" );
      print (STDERR "WRITING: Lost the will to live Error\nProblems for runnableDB writing output for \n[$err]") ;
      $self->throw( "Problems for runnableDB writing output for \n[$err]") ;
  }
 
 if($self->dependency){
     $self->adaptor->store_outputs($self, @output_ids) unless (scalar(@output_ids) == 0);
     $self->output_ids(@output_ids) unless (scalar(@output_ids) == 0);
 }
 ##############
 
 
 $self->stage('UPDATING');
  $self->status( "COMPLETED" );
  $self->update;

    print "debugjob\n"; 
  eval{
   $self->adaptor->update_completed_job($self);
  };
  if($err = $@){
      print STDERR ("Error updating completed job\n$err");
  }
  
  return 1;
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


=head2 status

  Title   : status
  Usage   : my $status = $job->status
  Function: Gets/Sets the job status
  Returns : status str.
  Args    : status str (opt)

=cut

sub status {
  my ($self,$arg) = @_;
  
  if (defined $arg){
    $self->{'_status'} = $arg;
  }

  return $self->{'_status'}; 
}

sub set_status{
  my ($self,$arg) = @_;
  
  $self->throw("no argument supplied in Job set_status") unless defined $arg;

  if( ! defined( $self->adaptor )) {
    return undef;
  }

  $self->{'_status'} = $arg;
 
  $self->adaptor->set_status( $self );
}

sub get_status{
  my ($self) = @_;
  
  if( ! defined( $self->adaptor )) {
    return undef;
  }
 
  return $self->adaptor->get_status( $self );
}

=head2 stage

  Title   : stage
  Usage   : my $stage = $job->stage
  Function: Gets/Sets the stage the job is currently in
  Returns : stage str.
  Args    : stage str (opt).

=cut

sub stage {
  my ($self,$arg) = @_;
  
  if (defined $arg){
    $self->{'_stage'} = $arg;
  }
  
  return $self->{'_stage'};
}


=head2 get_stage

  Title   : get_stage
  Usage   : my $stage = $job->get_stage
  Function: Get method to find out which stage a job is in
  Returns : stage str.
  Args    : 

=cut

sub get_stage{
  my ($self) = @_;
  
  if( ! defined( $self->adaptor )) {
    return undef;
  }
 
  return $self->adaptor->get_stage( $self );
}


sub set_stage{
  my ($self,$arg) = @_;
  
  $self->throw("no argument supplied in Job set_stage") unless defined $arg;

  if( ! defined( $self->adaptor )) {
    return undef;
  }
  $self->{'_stage'} = $arg;
 
  $self->adaptor->set_stage( $self );
}

sub make_filenames {
  my ($self) = @_;
  
  my $num = int(rand(10));
  my $dir = $NFSTMP_DIR;

# scp - one set of out files per job (even if batching together)
# this is a bit messy! added '.0' to $stub. This will be the master
# file containing QUEUE output. In runner.pl before each job is run
# replace 0 with the job ID to get one output file per $job.
# Change also Job::remove to do a glob on all these files. Yep it's
# nasty but it seems to work...


  my $stub = $self->adaptor->db->dbname.".job_".$self->dbID.".";
  $stub .= $self->analysis->logic_name.".";
  $stub .= time().".".int(rand(1000));

  $self->input_object_file($dir.$stub.".obj");
  $self->stdout_file($dir.$stub.".out");
  $self->stderr_file($dir.$stub.".err");

}

sub update {
    my ($self)= @_;

    $self->throw("Job update failed because job object has no db_adaptor attached")
    unless defined $self->adaptor;

    $self->adaptor->update($self);

}

sub update_completed{
  my ($self)=@_;
  eval{
    $self->adaptor->update_completed_job($self);
  };if($@){$self->throw ("Error updating completed job\n$@");}
}

    


sub create_queuelogfile {
  my ($self) = @_;
  
  my $num = int(rand(10));
  my $dir = $NFSTMP_DIR . "/$num/";
  if( ! -e $dir ) {
    system( "mkdir $dir" );
  }

  my $stub = $self->queue_id.".";
  $stub .= time().".".int(rand(1000));

  $self->queue_out($dir.$stub.".out");
  $self->queue_err($dir.$stub.".err");
}


=head2 filenames

  Title   : filenames
  Usage   : $job->stdout_file
  Function: dumb check method to see if job's files have been set
  Returns : 1 or 0
  Args    : 

=cut

sub filenames{
    my ($self) = @_;

    if (    $self->{'_stdout_file'} &&
            $self->{'_stderr_file'} &&
            $self->{'_input_object_file'}
        )
    {
	    return 1;
    }else{
        return 0;
    }
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
	$self->{_input_object_file} = $arg;
    }
    return $self->{_input_object_file};
}

=head2 QUEUE_id

  Title   : QUEUE_id
  Usage   : 
  Function: Get/set method for the QUEUE_id
  Returns : 
  Args    : 

=cut

sub queue_id{
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_queueid'} = $arg );
  $self->{'_queueid'};
}

sub queue_out{
  my ($self, $arg) = @_;
  (defined $arg) &&
    ( $self->{'_queueout'} = $arg );
  $self->{'_queueout'};
}

sub queue_err{
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

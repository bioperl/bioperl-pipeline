# BioPerl module for Bio::Pipeline::Job
#
# Based on the EnsEMBL Pipeline module Bio::EnsEMBL::Pipeline::Job
# originally written by Michele Clamp <michele@sanger.ac.uk>
#
# Cared for by Fugu Informatics Team <fuguteam@fugu-sg.org> 
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Job

=head1 SYNOPSIS

   my $input = Bio::Pipeline::Input->new(-name=>"sequence1",
                                         -tag=>"sequence",
                                         -input_handler=>$iohandler,
                                         -dynamic_arguments=>"-length 10",
                                         -job_id=>1);
  my $input = $io->fetch_input();

=head1 DESCRIPTION

The input/output object for reading input and writing output.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:
  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR  

Based on the EnsEMBL Pipeline module Bio::EnsEMBL::Pipeline::Job
originally written by Michele Clamp <michele@sanger.ac.uk>

Cared for by Fugu Informatics Team <fuguteam@fugu-sg.org>


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

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

=head2 new

  Title   : new
  Usage   : my $job = $->new
  Function: Constructor for Job object 
  Returns : L<Bio::Pipeline::Job> 
  Args    : -adaptor      the job adaptor object
            -id           the job dbID
            -process_id   the job process list
            -queue_id     the job queue id
            -inputs       an array ref of inputs for the job
            -stdout       the path to the stdout output file
            -stderr       the path to the stderr output file
            -input_object_file  the path the the .obj file
            -retry_count  the retry count of the job
            -status       the job status(FAILED,NEW,SUBMITTED);
            -stage        the job running stage(RUNNING,WRITING,READING)
            -output_ids   the list of outputids associated with the job
            -dependency   flag indicating where output of job is needed 
                          by downstream analysis

=cut

sub new {
    my ($class, @args) = @_;
    my $self = bless {},$class;

    my ($adaptor,$dbID,$process_id, $queueid,$inputs,$analysis,$stdout,$stderr,$obj_file, $retry_count,$status,$stage,$output_ids,$dependency) 
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

=head2 add_input

  Title   : add_input
  Usage   : $job->add_input($input)
  Function: Adds an input to the job
  Returns : 
  Args    : L<Bio::Pipeline::Input>

=cut

sub add_input {
    my ($self,$input) = @_;

    $input || $self->throw('trying to add input to Job without supplying argument');

    push (@{$self->{'_inputs'}},$input);
}


=head2 inputs

  Title   : inputs
  Usage   : my @inputs = $job->inputs
  Function: Holder for input objects
  Returns : An array of L<Bio::Pipeline::Input>
  Args    : NA

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


=head2 run

  Title   : run
  Usage   : $self->run
  Function: Runs  the job
  Returns : 1 if successful, throws in fails
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
	$self->throw("Cannot pipe STDOUT to stdout_file. Please check that your NFSTMP_DIR is writeable");
  }
        
  if( ! open ( STDERR, ">".$self->stderr_file )) {
    $self->set_status( "FAILED" );
	$self->throw("Cannot pipe STDERR to stderr_file. Please check that your NFSTMP_DIR is writeable.");
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
 
  $self->stage('UPDATING');
  $self->status( "COMPLETED" );
  $self->update;

  return 1;
}

=head2 set_status 

  Title   : set_status 
  Usage   : $job->set_status("FAILED");
  Function: sets the job status to either(FAILED,SUBMITTED,NEW,COMPLETED) in
            the job table 
  Returns : 
  Args    : Status string

=cut

sub set_status{
  my ($self,$arg) = @_;
  
  $self->throw("no argument supplied in Job set_status") unless defined $arg;

  if( ! defined( $self->adaptor )) {
    return undef;
  }

  $self->{'_status'} = $arg;
 
  $self->adaptor->set_status( $self );
}

=head2 get_status

  Title   : get_status
  Usage   : $job->get_status()
  Function: get the job status 
  Returns : Status String
  Args    : 

=cut

sub get_status{
  my ($self) = @_;
  
  if( ! defined( $self->adaptor )) {
    return undef;
  }
 
  return $self->adaptor->get_status( $self );
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

=head2 set_stage

  Title   : set_stage
  Usage   : $job->set_stage("WRITING");
  Function: sets the job status to either(WRITING,READING,RUNNING) in
            the job table
  Returns :
  Args    : Status string

=cut

sub set_stage{
  my ($self,$arg) = @_;
  
  $self->throw("no argument supplied in Job set_stage") unless defined $arg;

  if( ! defined( $self->adaptor )) {
    return undef;
  }
  $self->{'_stage'} = $arg;
 
  $self->adaptor->set_stage( $self );
}

=head2 make_filenames

  Title   : make_filenames
  Usage   : $job->make_filenames();
  Function: creates the stout,stderr,obj file names for the job 
  Returns :
  Args    : 

=cut

sub make_filenames {
  my ($self) = @_;
  
  my $num = int(rand(10));
  my $dir = $NFSTMP_DIR;
  my $stub='';
  $stub .= $self->adaptor->db->dbname."_" if $self->adaptor;
  $stub .= ".job_".$self->dbID."." if $self->dbID;
  $stub .= $self->analysis->logic_name.".";
  $stub .= time().".".int(rand(1000));

  $self->input_object_file($dir.$stub.".obj");
  $self->stdout_file($dir.$stub.".out");
  $self->stderr_file($dir.$stub.".err");

}

=head2 update

  Title   : update
  Usage   : $job->update();
  Function: updates the job status 
  Returns :
  Args    : 

=cut

sub update {
    my ($self)= @_;

    $self->throw("Job update failed because job object has no db_adaptor attached")
    unless defined $self->adaptor;

    $self->adaptor->update($self);

}

=head2 update_completed

  Title   : update_completed
  Usage   : $job->update_completed();
  Function: copy the job to the job_completed table 
  Returns :
  Args    : 

=cut

sub update_completed{
  my ($self)=@_;
  eval{
    $self->adaptor->update_completed_job($self);
  };if($@){$self->throw ("Error updating completed job\n$@");}
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

=head2 remove 

  Title   : remove 
  Usage   : $job->remove
  Function: remove job from job table,
            unlink stdout/stderr/obj fiels 
  Returns : 
  Args    :

=cut

sub remove {
  my $self = shift;
  
  if( -e $self->stdout_file ) { unlink( $self->stdout_file ) };
  if( -e $self->stderr_file ) { unlink( $self->stderr_file ) };
  if( -e $self->input_object_file ) { unlink( $self->input_object_file ) };

   if( defined $self->adaptor ) {
   $self->adaptor->remove( $self );
   }
}

#######################################
#GET/SETS from hereon
#######################################


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

=head2 output_ids

  Title   : output_ids
  Usage   : my $ids = $self->output_file
  Function: Get/set method for output ids
  Returns : string
  Args    : string

=cut

sub output_ids {

    my ($self) = @_;
    return @{$self->{'_output_ids'}};
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


sub queue_id {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{_queue_id} = $arg;
    }
    return $self->{_queue_id};
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

=head2 dependency

  Title   : dependency
  Usage   : $self->dependency(1);
  Function: Get/set method for the dependency flag of job 
  Returns : 1/0 
  Args    : 1/0

=cut

sub dependency {
    my ($self,$arg) = @_;
    if (defined($arg)) {

    $self->{'_dependency'} = $arg;
    }
    return $self->{'_dependency'};

}
1;

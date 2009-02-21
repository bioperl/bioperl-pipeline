#
# BioPerl module for Bio::Pipeline::Analysis
# 
# Based on the EnsEMBL module Bio::EnsEMBL::Analysis
# originally written by Michele Clamp <michele@sanger.ac.uk>
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Fugu Informatics Team <fuguteam@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Analysis

=head1 SYNOPSIS

    my $analysis = new Bio::Pipeline::Analysis(
        -id              => $id,
        -adaptor         =>$adaptor,
        -logic_name      => 'SWIRBlast',
        -db              => $db,
        -db_version      => $db_version,
        -db_file         => $db_file,
        -program         => $program,
        -program_version => $program_version,
        -program_file    => $program_file,
        -gff_source      => $gff_source,
        -gff_feature     => $gff_feature,
        -runnable        => $module,
        -analysis_parameters      => $analysis_parameters,
        -runnable_parameters      => $runnable_parameters,
        -created         => $created,
        -logic_name      => $logic_name,
        -iohandler       => $iohandler,
        -node_group      => $node_group,
        -io_map          => $io_map
        );

=head1 DESCRIPTION

This is the object representation of an analysis in the pipeline. Each
analysis will have a runnable which is in turn an interface to the
wrapper modules or scripts.

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

Based on Ensembl module Bio::EnsEMBL::Analysis originally written by
Michele Clamp, michele@sanger.ac.uk.

# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics Team

Email fuguteam@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Analysis;

use vars qw(@ISA);
use strict;
use Bio::Root::RootI;
use Bio::Root::IO;
use Bio::Pipeline::PipeConf qw (VERBOSE);
# Inherits from the base bioperl object
@ISA = qw(Bio::Root::Root);

=head2 new

  Title   : new
  Usage   : my $analysis = new Bio::Pipeline::Analysis(
                                  -id              => $id,
                                  -adaptor         =>$adaptor,
                                  -logic_name      => 'SWIRBlast',
                                  -db              => $db,
                                  -db_version      => $db_version,
                                  -db_file         => $db_file,
                                  -program         => $program,
                                  -program_version => $program_version,
                                  -program_file    => $program_file,
                                  -gff_source      => $gff_source,
                                  -gff_feature     => $gff_feature,
                                  -runnable        => $module,
                                  -analysis_parameters      => $analysis_parameters,
                                  -runnable_parameters      => $runnable_parameters,
                                  -created         => $created,
                                  -iohandler       => $iohandler,
                                  -node_group      => $node_group,
                                  -io_map          => $io_map
                                  );

  Function: constructor for analysis object
  Returns : L<Bio::Pipeline::Analysis> 
  Args    : -id           the analysis dbID
            -adaptor      the analysis adaptor object
            -logic_name   the logic name representing the analysis e.g. blast
            -db           the database name that the analysis uses (optional)
            -db_version   the version of the database if required
            -db_file      the name and path to the database file (e.g. a blast formatted database)
            -program      the name of the binary program that the analysis calls 
            -program_version the program version
            -program_file   the path to the binary
            -gff_source   the source name of the generic feature format for the features 
                          that that the analysis generates 
            -gff_feature  the type of generic feature that the analysis generates
            -runnable     the name of the runnable that the analysis uses 
                          (e.g. Bio::Pipeline::Runnable::Blast)
            -analysis_parameters   binary parameters
            -runnable_parameters   runnable parameters
            -created      the timestamp of the analysis entry in the Analysis table
            -iohandler    an array reference of iohandler that belong to this analysis.
            -node_group   the node group object that this analysis belongs to
            -io_map       a hash containing the mappings of iohandler for this analysis to the next

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = bless {},$class;
   
  my ($id,$adaptor,$db,$db_version,$db_file,$program,$program_version,$program_file,
      $gff_source,$gff_feature,$runnable,$analysis_parameters,$runnable_parameters,$data_monger_id,$created,
      $logic_name,$iohandler, $node_group, $io_map,$queue) = 

	  $self->_rearrange([qw(ID
	  			ADAPTOR
  				DB
	  			DB_VERSION
		  		DB_FILE
			  	PROGRAM
				  PROGRAM_VERSION
				  PROGRAM_FILE
		  		GFF_SOURCE
		  		GFF_FEATURE
			  	RUNNABLE
  				ANALYSIS_PARAMETERS
  				RUNNABLE_PARAMETERS
          DATA_MONGER_ID
		  		CREATED
			  	LOGIC_NAME
  			  IOHANDLER
         	NODE_GROUP
          IO_MAP
          QUEUE
  				)],@args);

  $self->dbID           ($id);
  $self->adaptor        ($adaptor);
  $self->db             ($db);
  $self->db_version     ($db_version);
  $self->db_file        ($db_file);
  $self->program        ($program);
  $self->program_version($program_version);
  $self->program_file   ($program_file);
  $self->runnable       ($runnable);
  $self->gff_source     ($gff_source);
  $self->gff_feature    ($gff_feature);
  $self->analysis_parameters     ($analysis_parameters);
  $self->runnable_parameters     ($runnable_parameters);
  $self->data_monger_id ($data_monger_id);
  $self->created        ($created);
  $self->logic_name     ($logic_name);
  $self->iohandler      ($iohandler);
  $self->io_map         ($io_map);
  $self->node_group     ($node_group);
  $self->queue($queue);
  $self->verbose($VERBOSE);

  return $self; # success - we hope!
}


=head2 test_and_setup

  Title   : test_and_setup 
  Usage   : Bio::Pipeline::Analysis->test_and_setup(1);
  Function: Basic test to check that the various analysis parameters provided are correct.
            For example, to check that the specified program, db_files exist and are
            accessible. It also tries to figure out the logic_name of the analysis,the program version
            and match the provided program to the runnable. 
  Returns : Throws if paths provided do not exist 
  Args    : verbose parameters 1/0 which sets the level of output print to stderr.

=cut


sub test_and_setup {
  my ($self,$verbose) = @_;
  if($self->runnable eq 'Bio::Pipeline::Runnable::DataMonger'){
      $self->debug("Skipping test for DataMonger");
      return;
  }
  my $program = $self->program;
  my $db_file = $self->db_file;

  #currently doesn't throw if no program or program file as some runnables don't need executables
  ($self->program || $self->program_file) && ($self->exists_program ||$self->throw("Program $program doesn't exist or not executable"));
  if($self->db_file){
    ($self->exists_db_file) || $self->throw("DB File $db_file doesn't exist");
  }
  $self->set_logic_name_if_needed($verbose);
  $self->set_program_version_if_needed($verbose);
  $self->match_program_to_runnable($verbose);
}

=head2 exists_program

  Title   : exists_program
  Usage   : $self->exists_program
  Function: Determines whether executable exists for the analysis
  Returns : int
  Args    : int

=cut

sub exists_program{
    my ($self) = @_;
    my $program = $self->program_file || $self->program;
    if( my $f = Bio::Root::IO->exists_exe($program) ) {
        return 1;
    }
    return 0;
}


=head2 fetch_next_analysis

  Title   : fetch_next_analysis
  Usage   : $self->fetch_prev_analysis
  Function: fetches the next analysis  based on current analysis
  Returns : L<Bio::Pipeline::Analysis>
  Args    :

=cut

sub fetch_next_analysis {
    my ($self) = @_;
    if(!$self->{'_next_analysis'}){
        push @{$self->{'_next_analysis'}} , $self->adaptor->fetch_next_analysis($self);
    }
    return @{$self->{'_next_analysis'}};
}

=head2 fetch_prev_analysis

  Title   : fetch_prev_analysis
  Usage   : $self->fetch_prev_analysis
  Function: fetches the previous analysis  based on current analysis
  Returns : L<Bio::Pipeline::Analysis>
  Args    : 

=cut

sub fetch_prev_analysis {
    my ($self) = @_;
    if(!$self->{'prev_analysis'}){
        push @{$self->{'_prev_analysis'}}, $self->adaptor->fetch_prev_analysis($self);
    }
    return @{$self->{'_prev_analysis'}};
}

=head2 exists_db_file

  Title   : exists_db_file
  Usage   : $self->exists_db_file
  Function: determine whetherthe  db file exists 
  Returns : int
  Args    : int

=cut

sub exists_db_file {
  my ($self) = @_;
  if (-e $self->db_file) {
    return 1;
  }
  return 0;
}

=head2 exists_runnable

  Title   : exists_runnable
  Usage   : $self->exists_runnable
  Function: determine whether the runnable exists
  Returns : int
  Args    : int

=cut

sub exists_runnable {
  my ($self) = @_;
  $self->runnable || $self->throw("Runnable not set yet");
  eval {
	my $runnable = $self->runnable;
        $runnable =~ s/\::/\//g;
        require "${runnable}.pm";
  };
  my $error;
  if ($error = $@) {
	$self->throw($error);
	return 0;
  } else {
	return 1;
  }

  #my $path= __FILE__;
  #$path=~m!(.*)/.*\.pm!;
  #my $dir = $1;
  #my @runnables = `ls $dir/Runnable/*.pm`;
  #foreach my $run(@runnables){
  #  $run =~  m!.*/(.*).pm!;
  #  if ($self->runnable =~ /Bio::Pipeline::Runnable::$1/){
  #    return 1;
  #  }
  #}
  #return 0;
}

=head2 set_logic_name_if_needed

  Title   : set_logic_name_if_needed
  Usage   : $self->set_logic_name_if_needed
  Function: set the logic name if not provided by 
            user by using the program name
  Returns : int
  Args    : int

=cut

sub set_logic_name_if_needed {
  my ($self,$verbose) = @_;
  if (!$self->logic_name){
    my $program = $self->program;
    #strip the program path
    $program =~  m!.*/(.*)!;
    $program = $1 || $program;
    
    $self->adaptor->update_logic_name($self->dbID,$program);
    $self->logic_name($program);
    return 1;
  }
  else {
      if($verbose){
          $self->debug("Logic name ".$self->logic_name."  already set.\n");
      }
  }

  
  return 0;
}    

=head2 set_program_version_if_needed

  Title   : set_program_version_if_needed
  Usage   : $self->set_program_version_if_needed
  Function: set the program version if not provided by user
  Returns : int
  Args    : int

=cut

sub set_program_version_if_needed {
   my ($self,$verbose) = @_;
   if (!$self->program_version) {
    my $program = $self->program;
    my $string;
    $string = $string || `$program --version 2>&1 `;
    #parse data format of decimal digits
    $string =~ /(\d+\/\d+\/\d+)|(\d+\.\d+)/;
    if($1){
      print STDERR "Updating Program version to $1\n";
      $self->adaptor->update_prog_version($self->dbID,$1);
      return 1;
    }
    else {
        if($verbose){
          $self->debug("unable to determine program version");
        }
      return 0;
    }
   }
   else {
        if($verbose){
          $self->debug("Program version already set");
        }
        return 0;
   }
}

=head2 match_logic_name_to_runnable

  Title   : match_logic_name_to_runnable
  Usage   : $self->match_program_to_runnable
  Function: matches the program to the runnable but looking in the Runnable Directory 
  Returns : 
  Args    : 

=cut

sub match_program_to_runnable {
    my ($self,$verbose) = @_;
    my $path= __FILE__;
    $path=~m!(.*)/.*\.pm!;
    my $dir = $1;
    if ($self->runnable){
      $self->exists_runnable || $self->throw("Runnable doesn't seem to exist inside $path");
      if($verbose){
          $self->debug("runnable already set to ".$self->runnable);
      }
      
    }
    else {
    #do matching by looking up Runnable Dir through ENV variable

      my @runnables = `ls $path/Runnable/*.pm`;
      foreach my $run(@runnables){
        $run =~  m!.*/(.*).pm!;
        my $runnable_name = "Bio::Pipeline::Runnable::$1";
        if ($self->program =~ /$1/i){
          $self->runnable($runnable_name);
          $self->adaptor->update_runnable($self->dbID,$runnable_name);            
          return 1;
        }
      }
    }
    return 0;
}

###########__GET/SETS FROM HERE ON #############

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor
  Function: Get/set method for the adaptor
  Returns : int
  Args    : int

=cut

sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_adaptor} = $arg;
    }
    return $self->{_adaptor};
}

=head2 data_monger

  Title   : data_monger
  Usage   : $self->data_monger
  Function: Get/set method for the data_monger
  Returns : int
  Args    : int

=cut

sub data_monger {
    my ($self,$data_monger) = @_;
    if(defined $data_monger){
        $self->{'_data_monger'} = $data_monger;
    }

    return $self->{'_data_monger'};
}


=head2 data_monger_id

  Title   : data_monger_id
  Usage   : $self->data_monger_id
  Function: Get/set method for the data_monger_id
  Returns : int 
  Args    : int 

=cut

sub data_monger_id {
    my ($self,$id) = @_;
    if(defined $id){
        $self->{'_data_monger_id'} = $id;
    }

    return $self->{'_data_monger_id'};
}


=head2 dbID

  Title   : dbID
  Usage   : $self->dbID
  Function: Get/set method for the dbID
  Returns : int
  Args    : int

=cut

sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_dbid} = $arg;
    }
    return $self->{_dbid};
}


=head2 id

  Title   : id
  Usage   : $self->id
  Function: Get/set method for the id
  Returns : int
  Args    : int

=cut

sub id {
    my ($self,$arg) = @_;
    $self->debug( "Analysis->id is deprecated. Use dbID!" );
    print STDERR caller;
    
    if (defined($arg)) {
	$self->{_dbid} = $arg;
    }
    return $self->{_dbid};
}


=head2 db

  Title   : db
  Usage   : $self->db
  Function: Get/set method for database
  Returns : String
  Args    : String

=cut

sub db {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_db} = $arg;
    }

    return $self->{_db};
}


=head2 db_version

  Title   : db_version
  Usage   : $self->db_version
  Function: Get/set method for the database version number
  Returns : int
  Args    : int

=cut

sub db_version {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_db_version} = $arg;
    }

    return $self->{_db_version};
}

=head2 db_file

  Title   : db_file
  Usage   : $self->db_file
  Function: Get/set method for the sequence database file
  Returns : string
  Args    : string

=cut

sub db_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_db_file} = $arg;
    }

    return $self->{_db_file};
}


=head2 program

  Title   : program
  Usage   : $self->program
  Function: Get/set method for the program name
  Returns : String
  Args    : String

=cut

sub program {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_program} = $arg;
    }

    return $self->{_program};
}


=head2 program_version

  Title   : program_version
  Usage   : $self->program_version
  Function: Get/set method for the program version number
  Returns : int
  Args    : int

=cut

sub program_version {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_program_version} = $arg;
    }

    return $self->{_program_version};
}

=head2 program_file

  Title   : program_file
  Usage   : $self->program_file
  Function: Get/set method for the program file
  Returns : string
  Args    : string

=cut

sub program_file {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_program_file} = $arg;
    }

    return $self->{_program_file};
}


=head2 runnable

  Title   : runnable
  Usage   : $self->runnable
  Function: Get/set method for the runnable name
  Returns : String
  Args    : String

=cut

sub runnable {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_runnable} = $arg;
    }

    return $self->{_runnable};
}

=head2 gff_source

  Title   : gff_source
  Usage   : $self->gff_source
  Function: Get/set method for the gff_source tag
  Returns : String
  Args    : String

=cut

sub gff_source {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_gff_source} = $arg;
    }

    return $self->{_gff_source};
}

=head2 gff_feature

  Title   : gff_feature
  Usage   : $self->gff_feature
  Function: Get/set method for the gff_feature tag
  Returns : String
  Args    : String

=cut

sub gff_feature {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_gff_feature} = $arg;
    }

    return $self->{_gff_feature};
}

=head2 analysis_parameters

  Title   : analysis_parameters
  Usage   : $self->analysis_parameters
  Function: Get/set method for the analysis parameter string
            which are the parameters passed directly to the binary
  Returns : String
  Args    : String

=cut

sub analysis_parameters {
    my ($self,$arg) = @_;

    if (defined($arg)) {
    	$self->{'_analysis_parameters'} = $arg;
    }

    return $self->{'_analysis_parameters'};
}

=head2 runnable_parameters

  Title   : runnable_parameters
  Usage   : $self->runnable_parameters
  Function: Get/set method for the runnable parameter string
            which are used only by the runnable
  Returns : String
  Args    : String

=cut

sub runnable_parameters {
    my ($self,$arg) = @_;

    if (defined($arg)) {
      #parse the string into array 
	    $self->{'_runnable_parameters'} =$arg; 
    }

    return $self->{'_runnable_parameters'};
}

=head2 created

  Title   : created
  Usage   : $self->created
  Function: Get/set method for the created time
  Returns : String
  Args    : String

=cut

sub created {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_created} = $arg;
    }

    return $self->{_created};
}

=head2 logic_name

  Title   : logic_name
  Usage   : $self->logic_name
  Function: Get/set method for the logic_name, the name under 
            which this typical analysis is known.
  Returns : String
  Args    : String

=cut


sub logic_name {
    my ($self, $arg ) = @_;
    if (defined $arg ) {
        $self->{_logic_name} = $arg;
    }
    return $self->{_logic_name};
}

=head2 iohandler

  Title   : iohandler
  Usage   : $self->iohandler
  Function: Get/set method for the iohandlers belonging to the analysis
  Returns : L<Bio::Pipeline::IOHandler> 
  Args    : L<Bio::Pipeline::IOHandler> 

=cut

sub iohandler {
    my ($self, $ioh) = @_;
    if($ioh) {
        foreach my $io (@{$ioh}){
            $io->analysis($self);
        }
        $self->{'_iohandler'} = $ioh;
    }
    return $self->{'_iohandler'};
}

=head2 queue

  Title   : queue
  Usage   : $self->queue
  Function: Get/set method for the queue on which jobs for this analysis are to be executed
  Returns : string
  Args    : string

=cut

sub queue {
  my ($self,$queue) = @_;
  if($queue) {
    $self->{'_queue'} = $queue;
  }
  return $self->{'_queue'};
}

=head2 io_map

  Title   : io_map
  Usage   : $self->io_map
  Function: Get/set method for the io_map
  Returns : Hash 
  Args    : Hash 

=cut

sub io_map{
    my ($self, $io_map) = @_;
    if($io_map) {
        $self->{'_io_map'} = $io_map;
    }
    return $self->{'_io_map'};
}

=head2 output_handler

  Title   : output_handler
  Usage   : $self->output_handler
  Function: Get method for the output_handlers, the IOhandlers used
            to store the results of this analysis
  Returns : String
  Args    : String

=cut


sub output_handler{
    my ($self) = @_;
    #search from list of iohandlers, cache if found
    if($self->{_output_handler}){
        return wantarray ? @{$self->{_output_handler}}:$self->{_output_handler};
    }
    else {
        my @ioh = @{$self->iohandler};
        my @output_ioh;
        foreach my $io (@ioh) {
            if ($io->type eq "OUTPUT"){
                push @output_ioh, $io;
            }
        }
        $self->{_output_handler} = \@output_ioh;
        return wantarray ? @{$self->{_output_handler}}: $self->{_output_handler};
    }
}

sub new_input_handler{
    my ($self) = @_;
    #search from list of iohandlers, cache if found
    if($self->{_new_input_handler}){
        return $self->{_new_input_handler};
    }
    else {
        my @ioh = @{$self->iohandler};
        foreach my $io (@ioh) {
            if ($io->type eq "NEW_INPUT"){
                $self->{_new_input_handler} = $io;
                return $self->{_new_input_handler};
            }
        }
        return undef;
    }
}

=head2 create_input_handler

  Title   : create_input_handler
  Usage   : $self->create_input_handler
  Function: Get/set method for the create_input_handler, the IOhandler used
            to create fixed inputs for this analysis
  Returns : IOHandler 
  Args    : IOHandler 

=cut


sub create_input_iohandler{
    my ($self) = @_;
    #search from list of iohandlers, cache if found
    if($self->{_create_input_handler}){
        return $self->{_create_input_handler};
    }
    else {
        my @ioh = @{$self->iohandler};
        my @cre_ioh =();
        foreach my $io (@ioh) {
            if ($io->type eq "CREATE_INPUT"){
                push @cre_ioh, $io;
            }
        }
        $self->{_create_input_handler} = \@cre_ioh;
        return $self->{_create_input_handler};
    }
}

=head2 node_group

  Title   : node_group
  Usage   : $self->node_group
  Function: Get/set method for the node_group that the analysis jobs belong to
  Returns : String
  Args    : String

=cut


sub node_group{
    my ($self, $arg ) = @_;

    if (defined $arg ) {
        $self->{_node_group} = $arg;
    }

    return $self->{_node_group};
}


1;

















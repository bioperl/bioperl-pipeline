# BioPerl runnable for Bio::Pipeline::Analysisbject for storing sequence analysis details
#
# Adapted from Michele Clamp's EnsEMBL::Analysis  <michele@sanger.ac.uk>
# Written by FuguI team (fugui@fugu-sg.org)
# You may distribute this runnable under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::Analysis.pm - Stores details of an analysis run

=head1 SYNOPSIS

    my $obj    = new Bio::Pipeline::Analysis(
        -id              => $id,
        -logic_name      => 'SWIRBlast',
        -db              => $db,
        -db_version      => $db_version,
        -db_file         => $db_file,
        -program         => $program,
        -program_version => $program_version,
        -program_file    => $program_file,
        -gff_source      => $gff_source,
        -gff_feature     => $gff_feature,
        -runnable          => $module,
        -runnable_version  => $module_version,
        -parameters      => $parameters,
        -created         => $created
        );

=head1 DESCRIPTION

Object to store details of an analysis run

=head1 CONTACT

FuguI team Singapore: fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Analysis;

use vars qw(@ISA);
use strict;
use Bio::Root::RootI;
use Bio::Root::IO;
# Inherits from the base bioperl object
@ISA = qw(Bio::Root::Root);


sub new {
  my($class,@args) = @_;
  
  my $self = bless {},$class;
   
  my ($id,$adaptor,$db,$db_version,$db_file,$program,$program_version,$program_file,
      $gff_source,$gff_feature,$runnable,$parameters,$created,
      $logic_name,$output_handler,$node_group ) = 

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
				PARAMETERS
				CREATED
				LOGIC_NAME
        OUTPUT_HANDLER
        NODE_GROUP
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
  $self->parameters     ($parameters);
  $self->created        ($created);
  $self->logic_name     ($logic_name);
  $self->output_handler ($output_handler);
  $self->node_group     ($node_group);

  return $self; # success - we hope!
}

sub test_and_setup {
  my ($self) = @_;
  my $program = $self->program;
  my $db_file = $self->db_file;
  $self->exists_program ||$self->throw("Program $program doesn't exist or not executable");
  if($self->db_file){
    ($self->exists_db_file) || $self->throw("DB File $db_file doesn't exist");
  }
  $self->set_logic_name_if_needed || (print "Logic name ".$self->logic_name."  already set.\n");
  $self->set_program_version_if_needed || (print "Program version not set. Either already set or cannot determine.\n");  
  $self->match_program_to_runnable || (print "Runnable not set, maybe already set or not found\n");
}

=head2 exists_program

  Title   : exists_program
  Usage   : $self->exists_program
  Function: Determines whether executable exists 
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

=head2 exists_db_file

  Title   : exists_db_file
  Usage   : $self->exists_db_file
  Function: determine where db file exists 
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

sub exists_runnable {
  my ($self) = @_;
  $self->runnable || $self->throw("Runnable not set yet");
  my $str = $ENV{PERL5LIB};
  my @str = split(":",$str);
  foreach my $s(@str){
    if ($s=~/bioperl-pipeline/){
     my @runnables = `ls $s/Bio/Pipeline/Runnable/*.pm`;
     foreach my $run(@runnables){
        $run =~  m!.*/(.*).pm!;
        if ($self->runnable =~ /Bio::Pipeline::Runnable::$1/){
          return 1;
        }
      }
    }
  }
  return 0;
}

=head2 set_logic_name_if_needed

  Title   : set_logic_name_if_needed
  Usage   : $self->set_logic_name_if_needed
  Function: set the logic name if not provided by user  
  Returns : int
  Args    : int

=cut

sub set_logic_name_if_needed {
  my ($self) = @_;
  if (!$self->logic_name){
    my $program = $self->program;
    #strip the program path
    $program =~  m!.*/(.*)!;
    $program = $1 || $program;
    
    $self->adaptor->update_logic_name($self->dbID,$program);
    $self->logic_name($program);
    return 1;
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
   my ($self) = @_;
   if (!$self->program_version) {
    my $program = $self->program;
    my $string = `$program -- >&/dev/null`; 
    $string = $string || `$program -v >&/dev/null`;
    $string =~ /([\d.]+)/;
    if($1){
      $self->adaptor->update_prog_version($self->dbID,$1);
      return 1;
    }
    else {
      $self->warn("unable to determine program version");
      return 0;
    }
   }
   return 0;
}

=head2 match_logic_name_to_runnable

  Title   : match_logic_name_to_runnable
  Usage   : $self->match_program_to_runnable
  Function: matches the program to the runnable but looking in the Runnable Directory 
  Returns : 
  Args    : 

=cut

sub match_program_to_runnable {
    my ($self) = @_;
    my $str = $ENV{PERL5LIB};
    my @str = split(":",$str);
    my $path;
    foreach my $s (@str){
      if($s =~ /bioperl-pipeline/){
        $path = $s;
        last;
       }
    }
    if ($self->runnable){
      $self->exists_runnable || $self->throw("Runnable doesn't seem to exist inside $path");
    }
    else {
    #do matching by looking up Runnable Dir through ENV variable

      my @runnables = `ls $path/Bio/Pipeline/Runnable/*.pm`;
      foreach my $run(@runnables){
        $run =~  m!.*/(.*).pm!;
        my $runnable_name = "Bio::Pipeline::Runnable::$1";
        if ($self->program =~ /$1/i){
          #replace slash with ::
#          $runnable_name =~ s/\//::/g;
          $self->runnable($runnable_name);
          $self->adaptor->update_runnable($self->dbID,$runnable_name);            
          return 1;
        }
      }
    }
    return 0;
}

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
    $self->warn( "Analysis->id is deprecated. Use dbID!" );
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

=head2 parameters

  Title   : parameters
  Usage   : $self->parameters
  Function: Get/set method for the parameter string
  Returns : String
  Args    : String

=cut

sub parameters {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	$self->{_parameters} = $arg;
    }

    return $self->{_parameters};
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

=head2 output_handler

  Title   : output_handler
  Usage   : $self->output_handler
  Function: Get/set method for the output_handler, the IOhandler used
            to store the results of this analysis
  Returns : String
  Args    : String

=cut


sub output_handler{
    my ($self, $arg ) = @_;

    if (defined $arg ) {
        $self->{_output_handler} = $arg;
    }

    return $self->{_output_handler};
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

















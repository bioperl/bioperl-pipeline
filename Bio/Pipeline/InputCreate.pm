#
# BioPerl module for Bio::Pipeline::InputCreate
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::InputCreate

=head1 SYNOPSIS

  use Bio::Pipeline::InputCreate;

 my $inc = Bio::Pipeline::InputCreate->new('-module'=>'setup_genewise','-rank'=>1,'-dbadaptor'=>$self->db);
 $inc->run();


=head1 DESCRIPTION

Object used for encapsulating "hacky" processing needed to setup
input and job tables. Pluggable into DataMonger object

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
  http://bugzilla.open-bio.org/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate;
use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::Input;
use Bio::Pipeline::Job;
use Bio::Pipeline::Runnable::DataMonger;


@ISA = qw(Bio::Root::Root);

=head2 new

  Title   : new
  Usage   : my $inc = Bio::Pipeline::InputCreate->new('-module'=>$module,'-rank'=>$rank,'-dbadaptor'=>$self->db,'-rule_group_id'=>$rgd)
  Function: constructor for InputCreate object 
  Returns : a new InputCreate object
  Args    : module, the list of inputcreate modules found in Bio::Pipeline::Filter::*
            rank specifies the order in which to apply the inputcreate in relation to others
            dbadaptor provides the handle to the pipeline database
            rule_group_id the rule group id of the jobs to be created by InputCreate

=cut

sub new {
    my ($caller ,@args) = @_;
     my $class = ref($caller) || $caller;

    # or do we want to call SUPER on an object if $caller is an
    # object?
    if( $class =~ /Bio::Pipeline::InputCreate::(\S+)/ ) {
      my ($self) = $class->SUPER::new(@args);
      $self->_initialize(@args);
      return $self;
    }
    else {
      my %param = @args;
      @param{ map { lc $_ } keys %param } = values %param; # lowercase keys
      my $module= $param{'-module'};
      my $rank= $param{'-rank'};
      my $rule_group_id = $param{'-rule_group_id'};
      $module || Bio::Root::Root->throw("You must provid a InputCreate module found in Bio::Pipeline::InputCreate::*");

      $module = "\L$module";  # normalize capitalization to lower case
      return undef unless ($class->_load_inputcreate_module($module));
      my ($self) =  "Bio::Pipeline::InputCreate::$module"->new(@args);
      $self->module($module);
      $self->rank($rank);
      $self->rule_group_id($rule_group_id);
      return $self;
    }
}

sub _initialize {
  my ($self,@args) = @_;
  my ($infile_suffix,$infile_dir,$dbadaptor) = $self->_rearrange([qw(INFILE_SUFFIX INFILE_DIR DBADAPTOR)],@args);
  $self->infile_suffix($infile_suffix) if $infile_suffix;
  $self->infile_dir($infile_dir) if $infile_dir;
  #$dbadaptor || $self->throw("InputCreate needs a dbadaptor to create new jobs and inputs");

  $self->dbadaptor($dbadaptor);
}

=head2 infile_dir

 Title   :   infile_dir
 Usage   :   $self->infile_dir()
 Function:   get/set
             holds the directory in which input files are
             found
 Returns :   a string
 Args    :   a string (optional)

=cut

sub infile_dir {
  my ($self, $infile_dir) = @_;
  if($infile_dir) {
      $self->{'_infile_dir'} = $infile_dir;
  }
  return $self->{'_infile_dir'};
}

=head2 infile

 Title   :   infile
 Usage   :   $self->infile()
 Function:   get/set
             holds the directory in which input files are
             found
 Returns :   a string
 Args    :   a string (optional)

=cut

sub infile{
  my ($self, $infile) = @_;
  if($infile) {
      $infile = Bio::Root::IO->catfile($self->infile_dir,$infile) if $self->infile_dir;
      $infile = $infile.$self->infile_suffix if $self->infile_suffix;
      $self->{'_infile'} = $infile;
  }

  return $self->{'_infile'};
}

=head2 infile_suffix

 Title   :   infile_suffix
 Usage   :   $self->infile_suffix()
 Function:   get/set
             holds the file extension of the input file
 Returns :   a string
 Args    :   a string (optional)

=cut

sub infile_suffix {
    my ($self,$val) = @_;
    if($val){
        $val = $val=~/^\.\S*/ ? $val : ".$val";
        $self->{'_infile_suffix'} = $val;
    }
    return $self->{'_infile_suffix'};
}

=head2 _load_inputcreate_module

  Title   : _load_inputcreate_module
  Usage   : $inc->_load_inputcreate_module("setup_genewise");
  Function: loads the input create module 
  Returns : a new InputCreate object
  Args    : module, the name of the module found in Bio::Pipeline::InputCreate

=cut

sub _load_inputcreate_module {
    my ($self, $module) = @_;
    $module = "Bio::Pipeline::InputCreate::" . $module;
    my $ok;

    eval {
      $ok = $self->_load_module($module);
    };
    if ($@) {
    print STDERR <<END;
$self: $module cannot be found
Exception $@
For more information about the Bio::Pipeline::InputCreate system please see the pipeline docs 
This includes ways of checking for formats at compile time, not run time
END
  ;
  }
  return $ok;
}

=head2 create_input

  Title   : create_input
  Usage   : $inc->create_input("inputname","3");
  Function: utility method for creating Bio::Pipeline::Input objects 
  Returns : L<Bio::Pipeline::Input>
  Args    : name: the name of the input
            ioh : the iohandler dbID of the input

=cut

sub create_input {
    my ($self,$name,$ioh,$tag) = @_;
    $name || $self->throw("Need an input name to create input");
    
    my $input_obj = Bio::Pipeline::Input->new(-name => $name,
                                              -tag  => $tag,
                                              -input_handler => $ioh);

    return $input_obj;
}

=head2 create_job

  Title   : create_job
  Usage   : $inc->create_job($analysis,[$input1,$input2]);
  Function: utility method for creating Bio::Pipeline::Job objects
  Returns : L<Bio::Pipeline::Job >
  Args    : analysis: a L<Bio::Pipeline::Analysis> object
            inputs: an array ref to the list of input belonging to the job

=cut


sub create_job {
    my ($self,$analysis,$input_objs) = @_;
    
    my $job = Bio::Pipeline::Job->new(-analysis => $analysis,
                                      -adaptor =>  $self->dbadaptor->get_JobAdaptor,
                                      -rule_group_id=>$self->rule_group_id,
                                      -inputs => $input_objs);
    return $job;
}

=head2 datatypes 

  Title   : datatypes
  Usage   : $inc->datatypes 
  Function: abstract method for returing the datatypes required by InputCreate object
  Returns : 
  Args    :

=cut

sub datatypes {
  my ($self) = @_;
  $self->throw_not_implemented();
}

sub rule_group_id {
  my ($self, $rule_group_id) = @_;
  if($rule_group_id) {
      $self->{'_rule_group_id'} = $rule_group_id;
  }
  return $self->{'_rule_group_id'};
}

=head2 dbID

  Title   : dbID
  Usage   : $inc->dbID
  Function: get set method for the dbID that the inputcreate dbID takes
  Returns :
  Args    :

=cut

sub dbID {
  my ($self,$dbID) = @_;

  if($dbID){
    $self->{'_dbID'} = $dbID;
  }
  return $self->{'_dbID'};
}

=head2 module

  Title   : module
  Usage   : $inc->module
  Function: get set method for the module that the inputcreate module takes
  Returns :
  Args    :

=cut

sub module {
  my ($self,$module) = @_;

  if($module){
    $self->{'_module'} = $module;
  }
  return $self->{'_module'};
}

=head2 rank

  Title   : rank
  Usage   : $inc->rank
  Function: get set method for the rank that the inputcreate module takes
  Returns :
  Args    :

=cut

sub rank {
  my ($self,$rank) = @_;

  if($rank){
    $self->{'_rank'} = $rank;
  }
  return $self->{'_rank'};
}

=head2 arguments 

  Title   : arguments 
  Usage   : $inc->arguments
  Function: get set method for the arguments that the inputcreate module takes 
  Returns :
  Args    :

=cut

sub arguments {
  my ($self,$arguments) = @_;

  if($arguments){
    $self->{'_arguments'} = $arguments;
  }
  return $self->{'_arguments'};
}


=head2 run

  Title   : run
  Usage   : $self->run();
  Function: abstract method for running the module 
  Returns :
  Args    :

=cut

sub run {
  my ($self) = @_;
  $self->throw_not_implemented();
}

=head2 dbadaptor

  Title   : dbadaptor
  Usage   : $self->dbadaptor();
  Function: get/set for dbadaptor 
  Returns :
  Args    :

=cut

sub dbadaptor {
  my ($self,$dbadaptor) = @_;

  if($dbadaptor){
    $self->{'_dbadaptor'} = $dbadaptor;
  }
  return $self->{'_dbadaptor'};
}

sub parse_params {
    my ($self,$string,$dash) = @_;
    $string = " $string"; #add one space for first param
    my @param_str = split(/\s-/,$string);
    shift @param_str;
    #parse the parameters
    my @params;
    foreach my $p(@param_str){
      my ($tag,$value) = $p=~/(\S+)\s+(.*)/;
      if($dash){
        push @params, ("-".$tag,$value);
      }
      else {
        push @params, ($tag,$value);
      }

    }
    return @params;
}


1;

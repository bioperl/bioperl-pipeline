
# BioPerl module for Bio::Pipeline::Transformer
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

Bio::Pipeline::Transformer The input object The  object for handling object 
transformation (conversion or filtering) during io handling.

=head1 SYNOPSIS

  use Bio::Pipeline::Transformer;

  my $transformer = new Bio::Pipeline::Transformer( -dbID => $transformer_id,
                                                -module => $module,
                                                -method => $method,
                                                -argument => $argument);

  my $objs = @{$transformer->run(\@obj)};

=head1 DESCRIPTION

  Module that provides a layer between the IOHandlers and converters and 
  filters 

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

=head1 AUTHOR - Shawn

Shawn Hoon shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Transformer;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $trans = Bio::Pipeline::Transformer->new('-module'=>'Bio::SeqFeatureIO',
                                                          '-method'=>"convert",
                                                          '-rank'  => 1);
  Function: constructor for transformer object
  Returns : L<Bio::Pipeline::Transformer>
  Args    : module the module name
            method the method to call that converts the object
            rank   the rank of the transformer if > 1r

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);

  my ($dbID, $module,$method, $analysis, $ioh,$rank)  =
      $self->_rearrange([qw(DBID
                            MODULE
                            METHOD
                            ANALYSIS
                            IOHANDLER
                            RANK
                        )],@args);

  $self->dbID($dbID);
  $self->module($module);
  $self->method($method);
  $self->rank($rank);
  $self->analysis($analysis) if $analysis;
  $self->iohandler($ioh) if $ioh;

  return $self;
}

=head2 run

  Title   : run
  Usage   : my $obj = $conv->run($obj);
  Function: does the actual conversion
  Returns : whatever object it is supposed to run to
  Args    : the input object to run

=cut

sub run {
	 my ($self, $input_ref) = @_;

   if(!$input_ref){
    $self->warn("Nothing provided to run Transformer on. Returning from run");
    return;
   }

   #put inputs in to an array
   my @inputs = ref $input_ref eq "ARRAY" ? @{$input_ref} : ($input_ref);
   $self->_input(\@inputs);

   #load the module
   my $obj         = $self->_object_transformer;
   
   my @methods = @{$self->method};
   #skip the constructor which is assume to be the first method
   shift @methods;

   #run each method consecutively
   foreach my $method(@methods){
    my @arguments = sort {$a->rank <=> $b->rank}@{$method->arguments} if ref($method->arguments);
    if(($#arguments >=0) && ref($arguments[0]) && (ref($arguments[0]) ne 'ARRAY') &&  $arguments[0]->isa("Bio::Pipeline::Argument")){
      @arguments           = $self->_format_input_arguments($input_ref,@arguments);
    }
    my $tmp1 = $method->name;
    #they should return an array ref
    $obj = $obj->$tmp1(@arguments);                                               
    if((ref($obj) eq 'ARRAY') && (scalar(@$obj) == 1)){                                                      
      $obj = $obj->[0];                                                           
    }                                                                           
  }    
  return $obj;
}


=head2 _format_input_arguments

  Title    : _format_input_arguments
  Function : formats the arguments for input, replace key word
             INPUT with the input object 
  Example  : $io ->_format_input_arguments($input_id,@args);
  Returns  : an array of arguments
  Args     : 

=cut

sub _format_input_arguments {
  my ($self,$input,@arguments) = @_;
  my @args;
  for (my $i = 0; $i <=$#arguments; $i++){
    if($arguments[$i]->tag){
      push @args, $arguments[$i]->tag;
    }
    if(($arguments[$i]->value =~ /[INPUT|\!INPUT\!]/ || $arguments[$i]->value =~/OUTPUT|\!OUTPUT\!/)){
      push @args, $input;
    }
    else {
      push @args, $arguments[$i]->value;
    }
  }                                                                                                                                                 
  return @args;                                                                                                                                     
}  

=head2 _load_obj
    
  Title    : _load_obj
  Function : loads an object
  Example  : $io->_load_obj("Bio::DB::Fasta","new");
  Returns  : the object
  Args     : module name, method name, and arguments
        
=cut   

sub _load_obj {
    my ($self,$module,$method,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $method = $method || 'new';
    
    $self->_load_module($module);
    
    my $obj = "${module}"->$method(@args);
    
    return $obj; 
}   

#get/set for the object doing the real transforming
#it will create the object if not already done so

sub _object_transformer {
  my ($self,$obj) = @_;
  if(!$self->{_object_transformer}){
    my @methods = @{$self->method};
    my $constructor = shift @methods;
    my @args        = @{$constructor->arguments};

    #arguments may / maynot be already formatted so check if its still a Bio::Pipeline::Argument
    #before formatting 
    if(($#args >=0) && ref($args[0]) && $args[0]->isa("Bio::Pipeline::Argument")){
      @args = $self->_format_input_arguments($self->_input,@args);
    }
    #load the module
    $self->{_object_transformer} = $self->_load_obj($self->module,$constructor->name,@args);
  }
  return $self->{_object_transformer};
}
   
  

=head2 in_datatype 

  Title   : in_datatype
  Usage   : $conv->in_datatype($id);
  Function: Returns the input datatype expected from the Transformer object 
  Returns : Bio::Pipeline::DataType
  Args    : None

=cut

sub in_datatype {
  my ($self) = @_;
  return $self->_object_transformer->in_datatype;
}

=head2 out_datatype 

  Title   : out_datatype
  Usage   : $transformer->out_datatype();
  Function: Returns the output datatype expected from the Transformer object 
  Returns : Bio::Pipeline::DataType
  Args    : None

=cut

sub out_datatype {
  my ($self) = @_;
  return $self->_object_transformer->out_datatype;
}

=head2 dbID

  Title   : dbID
  Usage   : $conv->dbID($id);
  Function: get/set for the dbID 
  Returns : 
  Args    : 

=cut

sub dbID {
    my ($self,$arg) = @_;
    if (defined($arg)) {
      $self->{'_dbID'} = $arg;
    }
    return $self->{'_dbID'};
}

#get/set for input ref, only set by sub routine run
sub _input {
    my ($self,$arg) = @_;
    if (defined($arg)) {
      $self->{'_input'} = $arg;
    }
    return $self->{'_input'};
}


=head2 module

  Title   : module
  Usage   : $conv->module($module);
  Function: get/set for the module
  Returns :
  Args    :

=cut

sub module {
    my ($self,$arg) = @_;
    if (defined($arg)) {
	    $self->{'_module'} = $arg;
    }
    return $self->{'_module'};
}

=head2 method

  Title   : method
  Usage   : $conv->method($method);
  Function: get/set for the module
  Returns :
  Args    :

=cut

sub method {
    my ($self,$arg) = @_;
    if (defined($arg)) {
	    $self->{'_method'} = $arg;
    }
    return $self->{'_method'};
}


=head2 rank

  Title   : rank
  Usage   : $conv->rank($rank);
  Function: get/set for the rank
  Returns :
  Args    :

=cut

sub rank{
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{'_rank'} = $arg;
    }

    return $self->{'_rank'};
}

=head2 analysis

  Title   : analysis
  Usage   : $conv->analysis($rank);
  Function: get/set for the analysis
  Returns :
  Args    :

=cut

sub analysis {
    my ($self,$analysis) = @_;
    if(defined($analysis)){
         $self->{'_analysis'} =$analysis;
    }
    return $self->{'_analysis'};
}

=head2 adaptor

  Title   : adaptor
  Usage   : $conv->adaptor($adaptor);
  Function: get/set for the adaptor
  Returns :
  Args    :

=cut

sub adaptor {
    my ($self, $arg) = @_;
    $self->{'_adaptor'} = $arg if(defined($arg));
    return $self->{'_adaptor'};
}

1;

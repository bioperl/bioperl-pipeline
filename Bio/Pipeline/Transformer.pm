#
# BioPerl module for Bio::Pipeline::Transformer
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Transformer input object

The  object for handling object transformation (conversion or filtering) during io handling.

=head1 SYNOPSIS

  use Bio::Pipeline::Transformer;

  my $transformer = new Bio::Pipeline::Transformer( -dbID => $transformer_id,
                                                -module => $module,
                                                -method => $method,
                                                -argument => $argument);

  my $objs = @{$transformer->run(\@obj)};

=head1 DESCRIPTION

  Module that provides a layer between the IOHandlers and converters and filters 

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

=head1 AUTHOR - Shawn

Shawn Hoon <shawnh@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

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

    if(defined $analysis){
        $self->warn("a Bio::Pipeline::Analysis object expected") unless($analysis->isa('Bio::Pipeline::Analysis'));
        $self->analysis($analysis);
    }else{
        $self->warn("analysis object is not defined");
    }
    
    if(defined $ioh){
        $self->warn("a Bio::Pipeline::IOHandler object expected") unless($ioh->isa('Bio::Pipeline::IOHandler'));
        $self->iohandler($ioh);
    }else{
        $self->warn("iohandler object is not defined");
    }
    
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
   my @inputs = ref $input_ref eq "ARRAY" ? @{$input_ref} : ($input_ref);
   my @methods = $self->method;
   my $constructor = shift @methods;
   my @args        = $constructor->arguments;
   my $obj         = $self->_load_obj($self->module,$constructor,@args);
   foreach my $method(@methods){
    my @arguments = sort {$a->rank <=> $b->rank}@{$method->argument};
    my @args = $self->_format_input_arguments($input_ref,@arguments);
    my $tmp1 = $method->method;
    my @obj = $obj->$tmp1(@args);                                               
    if(scalar(@obj) == 1){                                                      
      $obj = $obj[0];                                                           
    }                                                                           
    else {                                                                      
      $obj = \@obj;                                                             
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
    if($arguments[$i]->value eq 'INPUT'){
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
  Args     :
        
=cut    
        
sub _load_obj {
    my ($self,$module,$method,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $method = $method || 'new';
    
    $self->_load_module($module);
    
    my $obj = "${module}"->$method(@args);
    
    return $obj; 
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
    return @{$self->{'_method'}};
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

1;

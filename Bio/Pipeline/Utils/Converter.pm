#
# BioPerl module for Bio::Pipeline::Utils::Converter
#
# Cared for by Juguang Xiao  <juguang@fugu-sg.org> ,Kiran <kiran@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Utils::Converter input object

The converter object for handling object conversion during io handling.

=head1 SYNOPSIS

  use Bio::Pipeline::Utils::Converter;

  my $converter = new Bio::Pipeline::Utils::Converter( -dbID => $converter_id,
                                                -module => $module,
                                                -method => $method,
                                                -argument => $argument);

  my $converted_obj = $conveter->convert($obj);

=head1 DESCRIPTION

  Module to encapsulate a converter object

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

=head1 AUTHOR - Juguang, Kiran

Xiao Juguang <juguang@fugu-sg.org>
Kiran <kiran@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::Utils::Converter;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $converter = Bio::Pipeline::Utils::Converter->new('-module'=>'Bio::SeqFeatureIO',
                                                          '-method'=>"convert",
                                                          '-rank'  => 1);
  Function: constructor for converter object
  Returns : L<Bio::Pipeline::Utils::Converter>
  Args    : module the module name
            method the method to call that converts the object
            rank   the rank of the converter assuming that they may be
                   more than one converter

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);

  my ($dbID, $module,$method, $analysis, $ioh)  =
      $self->_rearrange([qw(DBID
                            MODULE
                            METHOD
                            ANALYSIS
                            IOHANDLER
                        )],@args);

  $self->dbID($dbID);
  $self->module($module);
  $self->method($method);
#  $self->rank($rank);

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

sub _initialize{
	my ($self) = @_;
	return;
}

=head2 convert

  Title   : convert
  Usage   : my $obj = $conv->convert($obj);
  Function: does the actual conversion
  Returns : whatever object it is supposed to convert to
  Args    : the input object to convert

=cut

sub convert {
	 my ($self, $input_ref) = @_;

	 $input_ref || $self->throw("Need a ref of array of input objects to convert");
    unless(ref($input_ref) eq "ARRAY"){
        $self->throw("The input of convert is supposed to be a ref of array");
    }

    my @inputs = @{$input_ref};
    my @outputs;
    foreach my $input (@inputs){
        my $output = $self->_convert_single($input);
        push @outputs, $output;
    }
    
    return \@outputs;
}


sub _convert_single{
    my ($self) = @_;    
    $self->throw("Not implemented. Please check the instance subclass.");
    
}

sub _load_converter_module{
	my ($self, $module) = @_;
	$module = "Bio::Pipeline::Utils::Converter::$module";
	my $ok;
	#eval{
	#	$ok = $self->_load_module($module);
	#};

	if($@){
		print STDERR <<END
$self: $module cannot be found
END
;
	}
	return $ok;
}

=head2 _create_obj

  Title   : _create_obj
  Usage   : my $obj = $conv->_create_obj($obj);
  Function: loads the object 
  Returns : whatever object it is supposed to create
  Args    :  the module name

=cut

sub _create_obj {
    my ($self,$module,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $self->_load_module($module);

    my $obj = "${module}"->new(@args);

    return $obj;
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

sub add_argument{
	my ($self, $arg) = @_;
	if(!defined($self->{'_argument'})){
		$self->{'_argument'} =();
	}
	push @{$self->{'_argument'}}, $arg;
}
 
=head2 argument

  Title   : argument
  Usage   : $conv->argument($argument);
  Function: get/set for the argument
  Returns :
  Args    :

=cut

sub arguments{
	my($self, $arg) = @_;
  if (defined($arg)) {
      $self->{'_argument'}= $arg;
   }
    return $self->{'_argument'};
}

=head2 analysis

The getter/setter of analysis

=cut 

sub analysis{
    my ($self, $anal) = @_;
    if(defined $anal){
        $self->throw(" a Bio::Pipeline::Analysis obj is wanted") 
            unless(ref $anal eq 'Bio::Pipeline::Analysis');
        $self->{_Bio_Pipeline_Converter_analysis} = $anal;
    }
    return $self->{_Bio_Pipeline_Converter_analysis};
}

sub iohandler{
    my ($self, $ioh) = @_;
    if(defined $ioh){
        $self->throw(" a Bio::Pipeline::IOHandler obj is wanted")
            unless(ref $ioh eq 'Bio::Pipeline::IOHandler');
        $self->{_Bio_Pipeline_Converter_iohandler} = $ioh;
    }
    return $self->{_Bio_Pipeline_Converter_iohandler};
}

1;

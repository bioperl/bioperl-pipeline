#
# BioPerl module for Bio::Pipeline::Converter
#
# Cared for by Kiran <kiran@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Converter input object

The converter object for handling object conversion during io handling.

=head1 SYNOPSIS

  use Bio::Pipeline::Converter;

  my $converter = new Bio::Pipeline::Converter( -dbID => $converter_id,
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

=head1 AUTHOR - Kiran 

Email kiran@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::Converter;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $converter = Bio::Pipeline::Converter->new('-module'=>'Bio::SeqFeatureIO',
                                                          '-method'=>"convert",
                                                          '-rank'  => 1);
  Function: constructor for converter object
  Returns : L<Bio::Pipeline::Converter>
  Args    : module the module name
            method the method to call that converts the object
            rank   the rank of the converter assuming that they may be
                   more than one converter

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);

  my ($dbID, $module,$method, $rank)  =
      $self->_rearrange([qw(DBID
                            MODULE
			    METHOD 
                            RANK 
                        )],@args);

  $self->dbID($dbID);
  $self->module($module);
  $self->method($method);
  $self->rank($rank);

  return $self;
}

=head2 convert

  Title   : convert
  Usage   : my $obj = $conv->convert($obj);
  Function: does the actual conversion
  Returns : whatever object it is supposed to convert to
  Args    : the input object to convert

=cut

sub convert {
    my ($self, $input) = @_;
    $input || $self->throw("Need an input object to convert");
    my $obj = $self->_create_obj($self->module);


	my @methods = sort {$a->rank <=> $b->rank} @{$self->method};
	foreach my $method (@methods){
				

	}
    my $method = $self->method;
    my $output = $obj->$method($input);
    return $output;
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


=head2 argument

  Title   : argument
  Usage   : $conv->argument($argument);
  Function: get/set for the argument
  Returns :
  Args    :

=cut

sub argument{
	my($self, $arg) = @_;
  if (defined($arg)) {
      $self->{'_argument'}= $arg;
   }
    return $self->{'_argument'};
}

1;

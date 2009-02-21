#
# Object for storing sequence analysis details
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon  <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code


=head1 NAME

Bio::Pipeline::DataType

=head1 SYNOPSIS

  use Bio::Pipeline::DataType;
  my $obj    = new Bio::Pipeline::DataType
      ('-objecttype'              => "Bio::SeqI",
       '-name'                    => "-sequence",
       '-reftype'                 => "ARRAY",
      );
   #  or

   # $range->isa('Bio::RangeI');
   my $obj = new Bio::Pipeline::DataType();
   my $dt = $obj->create_from_input($range);

=head1 DESCRIPTION

Object to represent a class of objects, used by Runnables for
matching inputs to get/sets

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

=head1 AUTHOR - FuguI Team

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::DataType;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $obj    = new Bio::Pipeline::DataType
                                            ('-objecttype'=> "Bio::SeqI",
                                             '-name'      => "-sequence",
                                             '-reftype'   => "ARRAY",
                                             );
  Function: this constructor should only be used in the IO_adaptor or IO objects.
            generates a new Bio::Pipeline::DataHandler
  Returns : L<Bio::Pipeline::DataType>
  Args    :

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);

  my ($object_type,$name,$ref_type)  =
      $self->_rearrange([qw(OBJECT_TYPE
			                      NAME
                            REFTYPE
			                      )],@args);

  $self->object_type($object_type);
  $self->name($name);
  $self->ref_type($ref_type);

  return $self;
}

=head2 create_from_input 

  Title   : create_from_input 
  Usage   : $self->create_from_input($input)
  Function: creates a datatype object from an input object 
  Returns : Bio::Pipeline::DataType 
  Args    : an object 

=cut

sub create_from_input {
  my $dummy = shift;
  my $input = shift;

  my $datatype;

  #can't figure out name..have to set it manually
  if (ref($input) eq ""){ #a scalar 
    $datatype = Bio::Pipeline::DataType->new(   
                -object_type    => "",
                -reftype        => "SCALAR",
                -name           => "",
            );

  }
  elsif (ref($input) eq "ARRAY"){#an array of objects
    my $first = $input->[0];
    
    $datatype = Bio::Pipeline::DataType->new(   
                -object_type    => ref($first),
                -reftype        => "ARRAY",
                -name           => "",
            );
  }
  else {# a single object
    $datatype = Bio::Pipeline::DataType->new(   
                -object_type    => ref($input),
                -reftype        => "SCALAR",
                -name           => "",
            );
  }
  return $datatype;
}

=head2 match 

  Title   : match 
  Usage   : $self->match($data_type)
  Function: checks where two data types match. 
  Returns : 1/0 
  Args    : Bio::Pipeline::DataType 

=cut

sub match {
    my ($self,$data_type) = @_;
    $data_type->isa("Bio::Pipeline::DataType") ||
        $self->throw("Need a Bio::Pipeline::DataType to check");

    my $obj_type = $self->object_type;
    my $name = $self->name;
    my $ref_type = $self->ref_type;

    my $q_obj_type = $data_type->object_type();
    my $q_ref_type = $data_type->ref_type();
    my $q_name = $data_type->name();

    my $class = $data_type->object_type;
    #if (($obj_type eq $q_obj_type) && ($name eq $q_name )
    #&&($ref_type eq $q_ref_type)){
    if (($obj_type eq $q_obj_type) &&($ref_type eq $q_ref_type))
        {#don't require name to match for now
        return 1;
    }
    else {
        return 0;
    }
}

=head2 object_type

  Title   : object_type
  Usage   : $self->object_type
  Function: Get/set method for the object_type
  Returns : string 
  Args    : string 

=cut

sub object_type {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_object_type} = $arg;
    }

    return $self->{_object_type};
}

=head2 name

  Title   : name
  Usage   : $self->name
  Function: Get/set method for the name string
  Returns : string
  Args    : string

=cut

sub name {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_name} = $arg;
    }

    return $self->{_name};
}

=head2 ref_type

  Title   : ref_type
  Usage   : $self->ref_type
  Function: Get/set method for the ref_type 
  Returns : int
  Args    : int

=cut

sub ref_type{
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_ref_type} = $arg;
    }

    return $self->{_ref_type};
}

1;

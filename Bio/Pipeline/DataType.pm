#
# Object for storing sequence analysis details
#
# Cared for by Shawn Hoon  <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::DataType - small object storing job status tags

=head1 SYNOPSIS

    my $obj    = new Bio::Pipeline::DataType
    ('-objecttype'              => "Bio::SeqI",
     '-name'                    => "-sequence",
     '-reftype'                 => "ARRAY",
     );
         or
     my $range = Bio::Range;
     my $obj = new Bio::Pipeline::DataType();
     my $dt = $obj->create_from_input($range);


=head1 DESCRIPTION

Stores the status of a job at a certain time

=head1 CONTACT


=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::DataType;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


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
  my ($self,$input) = @_;
  $input || $self->throw("Need an input");

  #can't figure out name..have to set it manually
  if (ref($input) eq ""){ #a scalar 
    $self->object_type("");
    $self->ref_type("SCALAR");
    $self->name("");
  }
  elsif (ref($input) eq "ARRAY"){#an array of objects
    my $first = $input->[0];
    (ref($first) ne "") || $self->throw("Array does not contain valid data types");
    $self->object_type(ref($first));
    $self->ref_type("ARRAY");
    $self->name("");
  }
  else {# a single object
    $self->object_type(ref($input));
    $self->ref_type("");
    $self->name("");
  }
  return $self;
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
    $data_type->isa("Bio::Pipeline::DataType") || $self->throw("Need a Bio::Pipeline::DataType to check");
    my $obj_type = $self->object_type;
    my $name = $self->name;
    my $ref_type = $self->ref_type;

    my $q_obj_type = $data_type->object_type();
    my $q_ref_type = $data_type->ref_type();
    my $q_name = $data_type->name();
    if (($obj_type eq $q_obj_type) && ($name eq $q_name ) &&($ref_type eq $q_ref_type)){
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
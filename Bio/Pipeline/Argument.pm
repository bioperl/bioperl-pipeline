#
# BioPerl module for Bio::Pipeline::Argument
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::Argument 


=head1 SYNOPSIS

This object is used by the IO adaptors to fetch data.

my $data_adaptor = Bio::Pipeline::Argument->new(-d


=head1 DESCRIPTION 

Arguments specifiy the adaptor methods and the correspoding 
arguments needed by a IO to fetch or store output. 

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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR 

Email fugui@fugu-sg.org 

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::Argument;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $io = Bio::Pipeline::Argument->new($dbid,$tag,$value,$rank,$dhid,$type)
  Function: this constructor should only be used in the Input object IO_adaptor or IO objects
            generates a new Bio::Pipeline::Argument. It may represent static arguments that
            are found in the argument table (tied to datahandlers) or dynamic ones found in the 
            dynamic_argument table (tied to Inputs)
  Returns : L<Bio::Pipeline::Argument>
  Args    : dbID: the dbID of the argument (optional)
            tag : the tag of the argument(optional)
            value: the value of the argument(required)
            type : the type of the arugment(required, SCALAR or ARRAY)
  
=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$tag,$value,$rank,$dhID,$type)=$self->_rearrange([qw(DBID
                                                     TAG 
                                                     VALUE
                                                     RANK
                                                     DHID
                                                     TYPE)],@args);

  #$rank || $self->throw("Argument constructor needs a rank");
  $value|| $self->throw("Argument needs a method arg.");
  #$type || $self->throw("Argument needs a type");
  $dbID && $self->dbID($dbID);
  $self->value($value);
  $self->type($type);
  $self->rank($rank);
  $tag && $self->tag($tag);
  $dhID  && $self->dhID($dhID); 

  return $self;
}    

=head1 Member variable access

These methods let you get at and set the member variables

=head2 dbID

  Title    : dbID
  Function : returns dbID
  Example  : $data_adaptor->dbID(); 
  Returns  : dbid of the data adaptor
  Args     : 

=cut
 
sub dbID {
    my ($self,$dbID) = @_;
    if($dbID){
        $self->{'_dbID'} = $dbID;
    }
    return $self->{'_dbID'};
}

=head2 dhID

  Title    : dhID
  Function : returns dhID
  Example  : $data_adaptor->dhID();
  Returns  : data handler for dynamic argument
  Args     :

=cut

sub dhID {
    my ($self,$dhID) = @_;
    if($dhID){
        $self->{'_dhID'} = $dhID;
    }
    return $self->{'_dhID'};
}

=head2 value

  Title    : value
  Function : returns value
  Example  : $Argument->value(); 
  Returns  : value of the Argument
  Args     : 

=cut
 
sub value{
    my ($self,$value) = @_;
    if($value){
      $self->{'_value'} = $value;
    }
    return $self->{'_value'};
}

sub tag {
    my ($self,$tag) = @_;
    if($tag){
      $self->{'_tag'} = $tag;
    }
    return $self->{'_tag'};
}

=head2 argument

  Title    : argument
  Function : returns argument
  Example  : $dh->adpator_arg(); 
  Returns  : argument of the Argument
  Args     : 

=cut
 
sub type{
    my ($self,$type) = @_;
    if($type){
      $self->{'_type'} = $type;
    }
    return $self->{'_type'};
}


=head2 rank

  Title    : rank
  Function : returns rank
  Example  : $dh->rank(); 
  Returns  : rank the Argument
  Args     : 


=cut
 
sub rank{
    my ($self,$rank) = @_;
    if($rank) {
      $self->{'_rank'} = $rank;
    }
    return $self->{'_rank'};
}

1;

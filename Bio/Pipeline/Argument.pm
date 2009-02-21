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

    use Bio::Pipeline::Argument;
    my $arg = new Bio::Pipeline::Argument(-dbID => $argument_id,
                                          -rank => $rank,
                                          -value=> $value,
                                          -tag  => $tag,
                                          -type => $type);


=head1 DESCRIPTION 

An encapsulation of the arguments to be passed to each datahandler
method using a tag value system.

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

Email fugui@fugu-sg.org 

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

package Bio::Pipeline::Argument;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

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
            type : the type of the argument(SCALAR(DEFAULT) or ARRAY)
            rank : the order of the argument in the method call, 
            eg. fetch(1,"swissprot");
            Argument 1 would have rank 1,
            Argument swissprot would have rank 2.
            If tag-value is used e.g. fetch(-id=>1, -db=>"swissprot")
            rank is probably not needed.

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

  defined $value || $self->throw("Argument needs a value tag.");
  $type  = $type || 'SCALAR';
  $rank = $rank || 1;
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

=head2 tag

  Title    : tag
  Function : returns tag
  Example  : $arg->tag ();
  Returns  : tag of the Argument
  Args     :

=cut

sub tag {
    my ($self,$tag) = @_;
    if($tag){
      $self->{'_tag'} = $tag;
    }
    return $self->{'_tag'};
}

=head2 type

  Title    : type
  Function : returns type
  Example  : $arg->type (); 
  Returns  : type of the Argument ('SCALAR' or 'ARRAY')
  Args     : 

=cut

sub type{
    my ($self,$type) = @_;
    if($type){
      $self->throw("Invalid argument type") unless (($type =~/SCALAR/m) || ($type=~/ARRAY/m));
      $self->{'_type'} = $type;
    }
    return $self->{'_type'};
}

=head2 rank

  Title    : rank
  Function : returns rank
  Example  : $argument->rank(); 
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

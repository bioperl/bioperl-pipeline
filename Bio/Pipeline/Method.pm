# BioPerl module for Bio::Pipeline::Method
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Method

=head1 SYNOPSIS

  use Bio::Pipeline::Method;
  my $data_handler = Bio::Pipeline::Method->new(-dbid=>1,
                                                -method=>"fetch_by_dbID",
                                                -argument=>\@arguments,
                                                -rank=>1);

=head1 DESCRIPTION

Methods specifiy the adaptor methods and the correspoding arguments
needed by a IO to fetch or store output.  The rank represents the
order in which they are called by IOHandler methods fetch_input,
write_output

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

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Method;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $data_handler = Bio::Pipeline::Method->new(-dbid=>1,
                                                   -method=>"fetch_by_dbID",
                                                   -argument=>\@arguments,
                                                   -rank=>1);
  Function: this constructor should only be used in the IO_adaptor or IO objects.
            generates a new Bio::Pipeline::Method
  Returns : a new Method object
  Args    :

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$name,$argument,$rank)=$self->_rearrange([qw(    DBID
                                                               NAME
                                                               ARGUMENT
                                                               RANK)],@args);

  $name || $self->throw("Method needs a method arg.");

  $dbID && $self->dbID($dbID);
  $self->{'_name'} = $name;
  $self->{'_argument'} = $argument;
  $self->{'_rank'} = $rank;

  return $self;
}


=head2 dbID

  Title    : dbID
  Function : returns dbID
  Example  : $data_adaptor->dbID();
  Returns  : dbid of the data adaptor
  Args     :

=cut

sub dbID {
    my ($self, $dbID) = @_;
    if(defined $dbID){
        $self->{'_dbid'} = $dbID;
    }
    return $self->{'_dbid'};
}

=head2 method

  Title    : method
  Function : returns method
  Example  : $Method->method();
  Returns  : method of the Method
  Args     :

=cut

sub name{
    my ($self, $name) = @_;
    if(defined $name){
        $self->{'_name'} = $name;
    }
    return $self->{'_name'};
}

=head2 argument

  Title    : argument
  Function : returns argument
  Example  : $dh->adpator_arg();
  Returns  : argument of the Method
  Args     :

=cut

sub arguments{
    my ($self,$val) = @_;
    if($val) {
        $self->{'_argument'} = $val;
    }
    return $self->{'_argument'};
}

=head2 rank

  Title    : rank
  Function : returns rank
  Example  : $dh->rank();
  Returns  : rank the Method
  Args     :

=cut

sub rank{
    my ($self) = @_;
    return $self->{'_rank'};
}

1;


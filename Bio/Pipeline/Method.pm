


# Let the code begin...

package Bio::Pipeline::Method;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $data_handler = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                   -method=>"fetch_by_dbID",
                                                   -argument=>\@arguments,
                                                   -rank=>1);
  Function: this constructor should only be used in the IO_adaptor or IO objects.
            generates a new Bio::Pipeline::DataHandler
  Returns : a new DataHandler object
  Args    :

=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$name,$argument,$rank)=$self->_rearrange([qw(    DBID
                                                               NAME
                                                               ARGUMENT
                                                               RANK)],@args);

#  $dbID || $self->throw("DataHandler constructor needs a dbID");
#  $rank || $self->throw("datahandle constructor needs a rank");
  $name || $self->throw("datahandler needs a method arg.");

  unless(ref($argument) eq 'ARRAY'){
        $self->throw("DataHandler expects argument as a reference of an array");
 }
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
  Example  : $datahandler->method();
  Returns  : method of the datahandler
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
  Returns  : argument of the datahandler
  Args     :

=cut

sub add_argument{
	my ($self, $argument) = @_;
	$argument || $self->throw("need a argument");
	push @{$self->{'_argument'}}, $argument;
}

sub arguments{
    my ($self) = @_;
    return $self->{'_argument'};
}


sub flush_arguments {
	my ($self) =  @_;
	@{$self->{'_argument'}} = ();
}

=head2 rank

  Title    : rank
  Function : returns rank
  Example  : $dh->rank();
  Returns  : rank the datahandler
  Args     :

=cut

sub rank{
    my ($self) = @_;
    return $self->{'_rank'};
}

1;


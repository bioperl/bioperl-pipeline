#
# BioPerl module for Bio::Pipeline::DataHandler
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME
Bio::Pipeline::DataHandler 


=head1 SYNOPSIS

This object is used by the IO adaptors to fetch data.

my $data_adaptor = Bio::Pipeline::DataHandler->new(-d


=head1 DESCRIPTION 

DataHandlers specifiy the adaptor methods and the correspoding 
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

package Bio::Pipeline::DataHandler;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $io = Bio::Pipeline::DataHandler->new(
 
  Function: this constructor should only be used in the IO_adaptor or IO objects.
            generates a new Bio::Pipeline::DataHandler
  Returns : a new DataHandler object 
  Args    : 
  
=cut

sub new {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$method,$argument,$rank)=$self->_rearrange([qw(    DBID
                                                               METHOD
                                                               ARGUMENT
                                                               RANK)],@args);

  $dbID || $self->throw("DataHandler constructor needs a dbID");
  $rank || $self->throw("datahandle constructor needs a rank");
  $method || $self->throw("datahandler needs a method arg.");

  $self->{'_dbid'} = $dbID;
  $self->{'_method'} = $method;
  $self->{'_argument'} = $argument;
  $self->{'_rank'} = $rank;
  
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
    my ($self) = @_;
    return $self->{'_dbid'};
}

=head2 method

  Title    : method
  Function : returns method
  Example  : $datahandler->method(); 
  Returns  : method of the datahandler
  Args     : 

=cut
 
sub method{
    my ($self) = @_;
    return $self->{'_method'};
}

=head2 argument

  Title    : argument
  Function : returns argument
  Example  : $dh->adpator_arg(); 
  Returns  : argument of the datahandler
  Args     : 

=cut
 
sub argument{
    my ($self) = @_;
    return $self->{'_argument'};
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

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

  use Bio::Pipeline::DataHandler;
  my $data_handler = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                     -method=>"fetch_by_dbID",
                                                     -argument=>\@arguments,
                                                     -rank=>1);

=head1 DESCRIPTION

DataHandlers specifiy the adaptor methods and the correspoding
arguments needed by a IO to fetch or store output.  The rank
represents the order in which they are called by IOHandler methods
fetch_input, write_output

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

package Bio::Pipeline::DataHandler;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new

  Title   : new
  Usage   : my $data_handler = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                   -method=>"fetch_by_dbID,
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
  my ($dbID,$method,$argument,$rank)=$self->_rearrange([qw(    DBID
                                                               METHOD
                                                               ARGUMENT
                                                               RANK)],@args);

  $dbID || $self->throw("DataHandler constructor needs a dbID");
  $rank || $self->throw("datahandle constructor needs a rank");
  $method || $self->throw("datahandler needs a method arg.");

  unless(ref($argument) eq 'ARRAY'){
	$self->throw("DataHandler expects argument as a reference of an array");
 } 
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

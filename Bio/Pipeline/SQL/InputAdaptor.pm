#
# BioPerl module for Bio::Pipeline::IO
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

package Bio::Pipeline::SQL::InputAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IO;
use Bio::Pipeline::Input;
@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head 1 Fetch methods 
These methods retrievs the adaptors

=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the input adaptor 
  Example  : $in_adpt = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 

=cut

sub fetch_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT name, input_dba_id
                              FROM input 
                              WHERE input_id = '$id'"
                              );
    $sth->execute();
    
    my ($name,$input_dba_id) = $sth->fetchrow_array;

    my $input_dba = $self->db->get_input_dba_adaptor->fetch_by_dbID($input_dba_id);

    my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -input_dba => $input_dba);
                                                    
    return $input;
    
}

sub store {}



1;


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
    
    my $sth = $self->prepare("SELECT name, input_dba_id,job_id
                              FROM input 
                              WHERE input_id = '$id'"
                              );
    $sth->execute();
    
    my ($name,$input_dba_id,$job_id) = $sth->fetchrow_array;

    $input_dba_id || $self->throw("No input adaptor for input with id $id");


    my $input_dba = $self->db->get_InputDBAAdaptor->fetch_by_dbID($input_dba_id);

    my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -job_id => $job_id,
                                    -input_dba => $input_dba);
                                                    
    return $input;
    
}

sub store {
    my ($self,$input) =@_;
    $input || $self->throw("Need input obj to store");

    my $sql = " INSERT INTO input (input_dba_id, job_id, name) 
                VALUES (?,?,?)";
    my $sth = $self->prepare($sql);
    eval{
        $sth->execute($input->input_dba->dbID,$input->job_id,$input->name);
    };if ($@){$self->throw("Error storing new input.\n$@");}


    $input->dbID($sth->{'mysql_insertid'});
    $input->adaptor($self);
    
    return $input->dbID;

}



1;


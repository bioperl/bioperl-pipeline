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
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::Input;
@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head 1 Fetch methods 


=cut

sub fetch_inputs_by_jobID {

  my ($self, $job_id) = @_;

  # getting the inputs
  my @inputs=() ;

  # Get the fixed inputs
  my $query = "SELECT input_id
               FROM input
               WHERE job_id = $job_id"; 
  my $sth = $self->prepare($query);
  $sth->execute;

  while (my ($input_id) = $sth->fetchrow_array){
      my $input = $self->db->get_InputAdaptor->
                         fetch_fixed_input_by_dbID($input_id);
      push (@inputs,$input);
  }

  #Get the new inputs (output of previous analysis input)
  $query = "SELECT input_id
               FROM new_input
               WHERE job_id = $job_id";
  $sth = $self->prepare($query);
  $sth->execute;

  while (my ($input_id) = $sth->fetchrow_array){
      my $input = $self->db->get_InputAdaptor->
                         fetch_new_input_by_dbID($input_id);
      push (@inputs,$input);
  }
  
  return @inputs;
}



=head2 fetch_fixed_input_by_dbID

  Title    : fetch_fixed_input_by_dbID
  Function : fetches the fixed input by dbID
  Example  : $input = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::Input 
  Args     : a string which specifies the id of the fixed input 

=cut

sub fetch_fixed_input_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT name, iohandler_id, job_id
                              FROM input 
                              WHERE input_id = '$id'"
                              );
    $sth->execute();
    
    my ($name,$iohandler_id, $job_id) = $sth->fetchrow_array;

    $iohandler_id || $self->throw("No input handler for input with id $id");

    my $input_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($iohandler_id);

    my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -input_handler => $input_handler,
                                    -job_id => $job_id);
                                                    
    return $input;
    
}

=head2 fetch_new_input_by_dbID

  Title    : fetch_new_input_by_dbID
  Function : fetches the new input by dbID
  Example  : $input = $ia ->fetch_new_input_by_dbID(1)
  Returns  : Bio::Pipeline::Input
  Args     : a string which specifies the id of the new input

=cut

sub fetch_new_input_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");

    my $sth = $self->prepare("SELECT name, job_id
                              FROM new_input
                              WHERE input_id = '$id'"
                              );
    $sth->execute();

    my ($name,$job_id) = $sth->fetchrow_array;
    $job_id || $self->throw("No Job associated for input with id $id");
    #my $job = $self->db->get_JobAdaptor->fetch_by_dbID($job_id);

    $sth = $self->prepare("SELECT analysis_id
                              FROM job 
                              WHERE job_id = '$job_id'"
                              );
    $sth->execute();

    my ($analysis_id) = $sth->fetchrow_array;

    $sth = $self->prepare("SELECT iohandler_id
                              FROM new_input_ioh
                              WHERE analysis_id = '$analysis_id'"
                              );
    $sth->execute();

    my ($iohandler_id) = $sth->fetchrow_array;
    $iohandler_id || $self->throw("No input handler for input with id $id");


    my $input_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($iohandler_id);

    my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -input_handler => $input_handler,
                                    -job_id => $job_id);

    return $input;

}

sub create_new_input {
    my ($self,$name, $job_id) =@_;

    my $sql = " INSERT INTO new_input (job_id, name)
                VALUES (?,?)";
    my $sth = $self->prepare($sql);
    eval{
        $sth->execute($job_id,$name);
    };if ($@){$self->throw("Error storing new input.\n$@");}

    my $id = $sth->{'mysql_insertid'};
    return $self->fetch_new_input_by_dbID($id);
}

sub copy_fixed_inputs {
    my ($self, $job_id, $new_job_id) = @_;
    my @inputs = ();
    
    my $query = "SELECT name, iohandler_id
                              FROM input
                              WHERE job_id = '$job_id'";

    my $sth = $self->prepare($query);
    $sth->execute();
    while (my ($name, $iohandler_id) = $sth->fetchrow_array){
      my $sql = " INSERT INTO input (name, iohandler_id, job_id) 
                VALUES (?,?,?)";
      my $sth = $self->prepare($sql);
      eval{
          $sth->execute($name, $iohandler_id,$new_job_id);
      };if ($@){$self->throw("Error copying fixed input.\n$@");}

      my $input_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($iohandler_id);
      my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -input_handler => $input_handler,
                                    -job_id => $new_job_id);
      push (@inputs,$input);
    }
    return @inputs;
}


sub store_fixed_input {
    my ($self,$input) =@_;
    $input || $self->throw("Need input obj to store");

    if (!defined ($input->dbID)) {
      my $sql = " INSERT INTO input (iohandler_id, job_id, name)
                 VALUES (?,?,?)";
      my $sth = $self->prepare($sql);
      eval{
          $sth->execute($input->input_handler->dbID,$input->job_id,$input->name);
      };if ($@){$self->throw("Error storing new input.\n$@");}


      $input->dbID($sth->{'mysql_insertid'});
      $input->adaptor($self);
    }
    else {
      my $sql = " INSERT INTO input (input_id, iohandler_id, job_id, name)
                VALUES (?,?,?,?)";
      my $sth = $self->prepare($sql);
      eval{
         $sth->execute($input->dbID, $input->input_handler->dbID,$input->job_id,$input->name);
      };if ($@){$self->throw("Error storing new input.\n$@");}

      $input->adaptor($self);
    }


    return $input->dbID;

}


sub remove_by_dbID{
    my ($self,@dbID) = @_;
    my $sth;
    if(!@dbID) {
        $sth = $self->prepare("DELETE FROM input");
    }
    else {
        my $list = join(",",@dbID);
        $sth = $self->prepare("DELETE FROM input where input_id in($list)");
    }
    $sth->execute();
    return;
}

sub remove_new_input_by_dbID {
    my ($self,@dbID) = @_;
    my $sth;
    if(!@dbID) {
        $sth = $self->prepare("DELETE FROM new_input");
    }
    else {
        my $list = join(",",@dbID);
        $sth = $self->prepare("DELETE FROM new_input where input_id in($list)");
    }
    $sth->execute();
    return;
}


1;


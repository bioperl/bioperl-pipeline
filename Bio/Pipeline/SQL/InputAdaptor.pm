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


=head1 Fetch methods

=cut

sub fetch_inputs_by_jobID {

  my ($self, $job_id) = @_;

  # getting the inputs
  my @inputs=() ;

  # Get the analysis to which this job belongs. do not call jobAdaptor->fetch_by_dbId and then analysis, goes into infinite loop
  my $query = "SELECT analysis_id
               FROM job 
               WHERE job_id = $job_id";
  my $sth = $self->prepare($query);
  $sth->execute;

  my ($analysis_id) = $sth->fetchrow_array;
  # Get the fixed inputs
  $query = "SELECT input_id
               FROM input
               WHERE job_id = $job_id"; 
  $sth = $self->prepare($query);
  $sth->execute;

  while (my ($input_id) = $sth->fetchrow_array){
      my $input = $self->db->get_InputAdaptor->
                         fetch_fixed_input_by_dbID($input_id, $analysis_id);
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
    my ($self,$id,$analysis_id) = @_;
    $id || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT name, tag,iohandler_id, job_id
                              FROM input 
                              WHERE input_id = '$id'"
                              );
    $sth->execute();
    
    my ($name,$input_tag,$iohandler_id, $job_id) = $sth->fetchrow_array;

    
    my $input_handler;
    if($iohandler_id){
        $input_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($iohandler_id);
        # Attach converters to the iohandler if any for this iohandler of the analysis that this input is fed into.
#        my $converters_ref = $self->db->get_AnalysisAdaptor->fetch_converters_by_iohandler($analysis_id, $iohandler_id);
        my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_dbID($analysis_id);
        
#        $input_handler->converters($converters_ref);
        $input_handler->analysis($analysis);
    }

    #fetch dynamic arguments if any
    $sth = $self->prepare("SELECT a.datahandler_id, a.tag,a.value,a.rank,a.type
                                   FROM dynamic_argument a
                                   WHERE a.input_id=?");
    $sth->execute($id); 

    my @args;
    while (my ($dh_id,$tag,$value,$rank,$type) = $sth->fetchrow_array()){
      my $arg = new Bio::Pipeline::Argument( -rank => $rank,
                                             -value=> $value,
                                             -tag  => $tag,
                                             -type => $type,
                                             -dhID => $dh_id);
      push @args, $arg;
    }

    my $dyn_args = scalar(@args) > 0 ? \@args: undef;



    my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -input_handler => $input_handler,
                                    -job_id => $job_id,
                                    -tag    => $input_tag,
                                    -dynamic_arguments=>\@args);
                                                    
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

    $sth = $self->prepare("SELECT analysis_id
                              FROM job 
                              WHERE job_id = '$job_id'"
                              );
    $sth->execute();

    my ($analysis_id) = $sth->fetchrow_array;
    

    my $input_handler = $self->db->get_IOHandlerAdaptor->fetch_new_input_ioh($analysis_id);

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

sub copy_inputs_map_ioh {
    my ($self,$job,$new_job,$tag) = @_;
    my @inputs;
    $job || $self->throw("Need the prev job");
    $new_job || $self->throw("Need the new job");

    foreach my $input($job->inputs){
      my $in;
      if($input->input_handler){
        my $map_ioh = $self->db->get_IOHandlerAdaptor->get_mapped_ioh($new_job->analysis->dbID,$input->input_handler->dbID);
        $in      = Bio::Pipeline::Input->new(-name => $input->name,-input_handler => $map_ioh,-job_id => $new_job->dbID,-tag=>$tag); 
        push @inputs, $in;
      }
      else {
        $in      = Bio::Pipeline::Input->new(-name => $input->name,-job_id => $new_job->dbID,-tag=>$tag); 
        push @inputs, $in;
      }
      $self->store_fixed_input($in);
    }
    return @inputs;
}

sub copy_fixed_inputs {
    my ($self, $job_id, $new_job_id) = @_;
    my @inputs = ();
    
    my $query = "SELECT name, tag,iohandler_id
                              FROM input
                              WHERE job_id = '$job_id'";

    my $sth = $self->prepare($query);
    $sth->execute();
    while (my ($name, $tag,$iohandler_id) = $sth->fetchrow_array){
      my $sql = " INSERT INTO input (name, tag,iohandler_id, job_id) 
                VALUES (?,?,?,?)";
      my $sth = $self->prepare($sql);
      eval{
          $sth->execute($name, $tag,$iohandler_id,$new_job_id);
      };if ($@){$self->throw("Error copying fixed input.\n$@");}

      my $input_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($iohandler_id) unless !$iohandler_id;
      my $input = Bio::Pipeline::Input->new (
                                    -name => $name,
                                    -tag  => $tag,
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
      my $sql = " INSERT INTO input (iohandler_id, job_id, name,tag)
                 VALUES (?,?,?,?)";
      my $sth = $self->prepare($sql);
      my $ioh_id = (ref($input->input_handler) && $input->input_handler->can("dbID")) ? $input->input_handler->dbID : $input->input_handler;
      my $tag = $input->tag || '';

      eval{
          $sth->execute($ioh_id,$input->job_id,$input->name,$tag);
      };if ($@){$self->throw("Error storing new input.\n$@");}

      $input->dbID($sth->{'mysql_insertid'});
      $sql = "INSERT INTO dynamic_argument(input_id,datahandler_id,tag,value,rank,type) values (?,?,?,?,?,?)";
      $sth = $self->prepare($sql);

      if ($input->dynamic_arguments){
          foreach my $arg (@{$input->dynamic_arguments}){
              $sth->execute($input->dbID,$arg->dhID,$arg->tag,$arg->value,$arg->rank,$arg->type);
          }
      }
      $input->adaptor($self);
    }
    else {
      my $sql = " INSERT INTO input (input_id, iohandler_id, job_id, name,tag)
                VALUES (?,?,?,?,?)";
      my $sth = $self->prepare($sql);
      eval{
         $sth->execute($input->dbID, $input->input_handler->dbID,$input->job_id,$input->name,$input->tag);
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


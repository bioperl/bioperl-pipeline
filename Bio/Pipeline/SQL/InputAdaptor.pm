#
# BioPerl module for Bio::Pipeline::InputAdaptor
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::InputAdaptor - input adaptors object for pipeline

=head1 SYNOPSIS

  my $in_adpt = Bio::Pipeline::InputAdaptor->new($db);
  $in_adpt->fetch_fixed_input_by_dbID(1);
  $in_adpt->create_new_input($name,$job_id);
  $in_adpt->copy_inputs_map_ioh($job,$new_job);
  $in_adpt->store_fixed_input($input);
  $in_adpt->femove_by_dbID($input->dbID);

=head1 DESCRIPTION

The adaptor for input objects

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - 

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut



package Bio::Pipeline::SQL::InputAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::Input;
@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);



=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the input adaptor 
  Example  : $in_adpt = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 

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
      if($analysis_id){
        my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_dbID($analysis_id);
        $analysis || $self->throw("Unable to fetch analysis $analysis_id");
        $input_handler->analysis($analysis);
        my $trans_ref = $self->db->get_AnalysisAdaptor->fetch_transformer_by_analysis_iohandler($analysis,$input_handler);
        $input_handler->transformers($trans_ref) if ($trans_ref);

      }
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
                                    -dbID=>$id,
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
                                    -dbID=>$id,
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
      my $map_ioh;
      if($input->input_handler){
        $map_ioh = $self->db->get_IOHandlerAdaptor->get_mapped_ioh($new_job->analysis->dbID,$input->input_handler->dbID);
      }
      else {
        $map_ioh = $self->db->get_IOHandlerAdaptor->get_mapped_ioh($new_job->analysis->dbID);
      }

        #heuristically look for file tag, need to fix to avoid hardcoding of infile -- shawn
      if($map_ioh && ($tag ne 'infile')){
        my $trans_ref = $self->db->get_AnalysisAdaptor->fetch_transformer_by_analysis_iohandler($new_job->analysis,$map_ioh);
       $map_ioh->transformers($trans_ref) if ($trans_ref);
        if(!$tag && ($map_ioh->file_path || $map_ioh->file_suffix)){
            $tag = 'input';
        }
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


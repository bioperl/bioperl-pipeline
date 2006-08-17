# Perl module for Bio::EnsEMBL::Pipeline::DBSQL::AnalysisAdaptor
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 05.09.2000
# Last modified : 05.09.2000 by Arne Stabenau
#
# Copyright EMBL-EBI 2000
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Pipeline::DBSQL::AnalysisAdaptor

=head1 SYNOPSIS

  $analysisAdaptor = $dbobj->getAnalysisAdaptor;
  $analysisAdaptor = $analysisobj->getAnalysisAdaptor;


=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class Analysis.
  There should be just one per application and database connection.


=head1 CONTACT

    Contact Arne Stabenau on implemetation/design detail: stabenau@ebi.ac.uk
    Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::SQL::AnalysisAdaptor;

use Bio::Pipeline::Analysis;
use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Root::Root;
use Bio::Pipeline::Transformer;

use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Pipeline::SQL::BaseAdaptor);


=head2 fetch_by_dbID

  Title   : fetch_by_dbID
  Usage   : my $analysis = $adaptor->fetch_by_dbID
  Function: Retrieves an analysis from database by internal id
  Returns : throws exception when something goes wrong.
            undef if the id is not in the db.
  Args    :

=cut

sub fetch_by_dbID {
  my ($self,$id) = @_;

  if( defined $self->{'_cache'}->{$id} ) {
    return $self->{'_cache'}->{$id};
  }

  my $sth = $self->prepare( q{
    SELECT  analysis_id, logic_name,
            program,program_version,program_file,
            data_monger_id,
            db,db_version,db_file,
            runnable,
            gff_source,gff_feature,
            created, analysis_parameters,runnable_parameters,node_group_id,queue
    FROM    analysis 
    WHERE   analysis_id = ?});

  $sth->execute( $id );
  my ($analysis_id,$logic_name,$program,$program_version,$program_file,$data_monger_id,
      $db,$db_version,$db_file,$runnable,$gff_source,$gff_feature,$created,
      $analysis_parameters,$runnable_parameters,$node_group_id,$queue) = $sth->fetchrow_array;

  if( ! defined $analysis_id) {
    return undef;
  }

  my $node_group = $self->db->get_NodeGroupAdaptor->fetch_by_dbID($node_group_id);
  

  my $query = " SELECT  DISTINCT ai.iohandler_id 
                FROM    analysis_iohandler ai
                WHERE   ai.analysis_id = $id";
                        
  $sth = $self->prepare($query);                  
  $sth->execute ();

  my @iohs;
  while (my ($ioid) = $sth->fetchrow_array){
      push @iohs, $self->db->get_IOHandlerAdaptor->fetch_by_dbID($ioid);
  }

  $query = " SELECT  prev_iohandler_id, map_iohandler_id
                FROM    iohandler_map  
                WHERE   analysis_id = $id";


  $sth = $self->prepare($query);
  $sth->execute ();
  my %iomap;
  while (my ($prev_ioid, $map_ioid) = $sth->fetchrow_array){
      my $map_ioh = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($map_ioid);
      $iomap{$prev_ioid} = $map_ioh;
  }

  #create the analysis object
  my $anal = new Bio::Pipeline::Analysis (  -ID             => $analysis_id,
                                            -ADAPTOR        => $self,
                                            -DB             => $db,
                                            -DB_VERSION     => $db_version,
                                            -DB_FILE        => $db_file,
                                            -PROGRAM        => $program,
                                            -PROGRAM_FILE   => $program_file,
                                            -PROGRAM_VERSION=> $program_version, 
                                            -GFF_SOURCE     => $gff_source,
                                            -GFF_FEATURE    => $gff_feature,
                                            -RUNNABLE       => $runnable,
                                            -ANALYSIS_PARAMETERS     => $analysis_parameters,
                                            -RUNNABLE_PARAMETERS =>$runnable_parameters,
                                            -DATA_MONGER_ID => $data_monger_id,
                                            -CREATED        => $created,
                                            -LOGIC_NAME     => $logic_name,
                                            -IOHANDLER      =>\@iohs,
                                            -NODE_GROUP     => $node_group,
                                            -QUEUE          => $queue,
                                            -IO_MAP         => \%iomap);

  $self->{'_cache'}->{$id} = $anal;

  #fetch transformers for each iohandler associated with an iohandler for
  #this analysis if present
  foreach my $ioh(@iohs) {
    my $trans_ref  = $self->fetch_transformer_by_analysis_iohandler($anal, $ioh);
    $ioh->transformers($trans_ref) if defined $trans_ref;
  }
  return $anal;
}

sub fetch_transformer_by_analysis_iohandler {
    my ($self, $anal, $ioh) = @_;

    my $query = " SELECT  ai.transformer_id, ai.transformer_rank
                   FROM    analysis_iohandler ai
                   WHERE   ai.analysis_id = ? AND ai.iohandler_id = ?
                   AND     ai.transformer_id != 'NULL' ";

    my $sth = $self->prepare($query);
    $sth->execute ($anal->dbID, $ioh->dbID);

    my @trans;
    while (my ($trans_id,$rank) = $sth->fetchrow_array){
      defined $trans_id || next;
      my $trans= $self->db->get_TransformerAdaptor->fetch_by_dbID($trans_id);
      $trans || next;
      $trans->rank($rank);
      push @trans,$trans;
    }
    return \@trans if $#trans >= 0;
    return undef;
}



=head2 fetch_next_analysis

  Title   : fetch_next_analysis
  Usage   : my $analysis = $adaptor->fetch_next_analysis
  Function: fetches the next analysis based on current analysis
  Returns : the next analysis based on rules, undef if not found
  Args    : L<Bio::Pipeline::Analysis>

=cut

sub fetch_next_analysis {
    my ($self,$anal,$rule_grp_id,) = @_;

    #grab analysis based on current analsyis

    my @rules = grep{($_->current) && ($_->current->dbID == $anal->dbID)} $self->db->get_RuleAdaptor->fetch_all;

    #if rule_group_provided, select next analysis within the group
    my @analysis;
      foreach my $rule(@rules){
        if($rule_grp_id && ($rule->rule_group_id == $rule_grp_id)){
          push @analysis, $self->fetch_by_dbID($rule->next->dbID);
        }
        else {
          push @analysis, $self->fetch_by_dbID($rule->next->dbID);
        }

    }
    return @analysis;
}

=head2 fetch_prev_analysis

  Title   : fetch_prev_analysis
  Usage   : my $analysis = $adaptor->fetch_prev_analysis
  Function: fetches the previous analysis based on current analysis
  Returns : the prev analysis based on rules, undef if not found
  Args    : L<Bio::Pipeline::Analysis>

=cut

sub fetch_prev_analysis {
    my ($self,$anal) = @_;
    my @rules = $self->db->get_RuleAdaptor->fetch_all;
    my @analysis;
    foreach my $rule(@rules){
      if(defined ($rule->next) && $rule->next->dbID == $anal->dbID){
          push @analysis, $self->fetch_by_dbID($rule->current->dbID);
      }
    }
    return @analysis;
}

#####################################################################3
=head2 fetch_analysis_iohandler

  Title   : fetch_analysis_iohandler
  Usage   : my $analysis = $adaptor->fetch_analysis_iohandler
  Function: fetches a particular iohandler for a particular analysis 
  Returns : throws exception when something goes wrong.
            undef if the id is not in the db.
  Args    : L<Bio::Pipeline::Analysis>

=cut

sub fetch_analysis_iohandler{
  my ($self,$analysis) = @_;

  my $query = "SELECT iohandler_id
               FROM analysis_iohandler ai, iohandler ioh
               WHERE ai.analysis_id=? AND ioh.type=?";
	
  my $sth = $self->prepare($query);
  $sth->execute($analysis->dbID,'INPUT_CREATION');
  my ($io_id) = $sth->fetchrow_array;
  if($io_id){
    my $ioh = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($io_id) || $self->throw("Unable to fetch iohandler $io_id");
    return $ioh;
  }
  return undef;

}

#############################################################################
sub fetch_all {
    my ($self) = @_;
    my @analysis;
    my $sth = $self->prepare("SELECT analysis_id FROM analysis");
    $sth->execute();
    while (my ($id) = $sth->fetchrow_array){
        push @analysis, $self->fetch_by_dbID($id);
    }
    return @analysis;

}


sub db {
  my ( $self, $arg )  = @_;
  ( defined $arg ) &&
    ($self->{'_db'} = $arg);
  $self->{'_db'};
}

sub deleteObj {
  my ($self) = @_;
 my @dummy = values %{$self};
  foreach my $key ( keys %$self ) {
    delete $self->{$key};
  }
  foreach my $obj ( @dummy ) {
    eval {
      $obj->deleteObj;
    }
  }
}


sub store {
    my ($self,$analysis) = @_;
    #return $analysis->dbID if defined ($analysis->dbID);

    if (!defined ($analysis->dbID)) {
	my $sth = $self->prepare( q{
	    INSERT INTO analysis
		SET created = now(),
		logic_name = ?,
		db = ?,
		db_version = ?,
		db_file = ?,
		program = ?,
		program_version = ?,
		program_file = ?,
		analysis_parameters = ?,
    runnable_parameters=?,
		runnable = ?,
		gff_source = ?,
    queue =?,
		gff_feature = ? } );

	$sth->execute
	    ( $analysis->logic_name,
	      $analysis->db,
	      $analysis->db_version,
	      $analysis->db_file,
	      $analysis->program,
	      $analysis->program_version,
	      $analysis->program_file,
	      $analysis->analysis_parameters,
	      $analysis->runnable_parameters,
	      $analysis->runnable,
	      $analysis->gff_source,
        $analysis->queue,
	      $analysis->gff_feature
	      );
	my $dbid = $sth->{mysql_insertid};
	$analysis->dbID($dbid);
     }
     else {
        my $sth = $self->prepare( q{
            INSERT INTO analysis
                SET 
                analysis_id = ?,
                created = now(),
                logic_name = ?,
                db = ?,
                db_version = ?,
                db_file = ?,
                program = ?,
                program_version = ?,
                program_file = ?,
                analysis_parameters = ?,
                runnable_parameters = ?,
                runnable = ?,
                gff_source = ?,
                queue      = ?,
                gff_feature = ? } );

        $sth->execute
            ( $analysis->dbID,
              $analysis->logic_name,
              $analysis->db,
              $analysis->db_version,
              $analysis->db_file,
              $analysis->program,
              $analysis->program_version,
              $analysis->program_file,
              $analysis->analysis_parameters,
              $analysis->runnable_parameters,
              $analysis->runnable,
              $analysis->gff_source,
              $analysis->queue,
              $analysis->gff_feature
              );
      }
      if (defined $analysis->data_monger) {
          $self->db->get_DataMongerAdaptor->store($analysis->data_monger, $analysis->dbID);
          #next; 
      }
      my $nodegroup_adaptor = $self->db->get_NodeGroupAdaptor;
      #foreach my $node_group($analysis->node_group) {
        #check if it exitst in the db and do not store if it already exists
      if(defined($analysis->node_group)) {
        if (! defined ($nodegroup_adaptor->fetch_by_dbID($analysis->node_group->id))) {
           $nodegroup_adaptor->store($analysis->node_group);
        }
      }

     my $output_handler = $analysis->output_handler;
     $self->_store_analysis_iohandler($analysis);

     my @ioh = @{$analysis->iohandler};

     if (defined ($analysis->io_map)) {
	     my %iomap = %{$analysis->io_map};

 	    foreach my $pre_ioh_id (keys %iomap){
        	 my $map_ioh_id = $iomap{$pre_ioh_id}->dbID;
     	    	 my $sth = $self->prepare("INSERT INTO iohandler_map
                                   SET analysis_id = ?,
                                       prev_iohandler_id = ?
                                       map_iohandler_id = ?");
     		    $sth->execute($analysis->dbID,$pre_ioh_id, $map_ioh_id);
    	     }
     }

	$self->{'_cache'}->{$analysis->dbID} = $analysis;
      return $analysis->dbID;
}
sub _store_analysis_iohandler{
    my ($self, $analysis) = @_;
    my @iohs = @{$analysis->iohandler};
    foreach my $ioh (@iohs){
        my $tran_ref = $ioh->transformers;
        if(defined $tran_ref){
            foreach my $tran(@{$tran_ref}){
                next unless defined $tran;
                my $sql =
                    "INSERT INTO analysis_iohandler
                    SET analysis_id = ?, iohandler_id = ?, transformer_id = ?,transformer_rank = ?";
                my $sth = $self->prepare($sql);
                $sth->execute($analysis->dbID, $ioh->dbID, $tran->dbID, $tran->rank);
            }
        }else{
            my $sql =
                "INSERT INTO analysis_iohandler
                SET analysis_id = ?, iohandler_id = ?";
            my $sth = $self->prepare($sql);
            $sth->execute($analysis->dbID, $ioh->dbID);
        }
    }
}

sub update_logic_name {
    my ($self,$dbID,$program) = @_;
    ($dbID && $program) || $self->throw("Need both a dbID and a program");
    my $sth = $self->prepare("UPDATE analysis SET logic_name='$program' WHERE analysis_id=$dbID");
    $sth->execute();
    if($@){
        $self->throw("Attempt to update analysis logic name failed .\n$@");
    }
}

sub update_prog_version {
  my ($self,$dbID,$prog_version) = @_;
  my $sth = $self->prepare("UPDATE analysis SET program_version='$prog_version' WHERE analysis_id=$dbID");
  $sth->execute();
  if($@){
      $self->throw("Attempt to update program version failed. \n $@");
  }
}

sub update_runnable {
    my ($self,$dbID,$runnable) = @_;
    my $sth = $self->prepare("UPDATE analysis SET runnable='$runnable' WHERE analysis_id=$dbID");
    $sth->execute();
    if($@){
      $self->throw("Attempt to update runnable failed.\n $@");
    }
}

# A generic method for the internal use to update the column of analysis table.
sub _update_text{
	my ($self, $dbID, $name, $value) =  @_;
	my $query = "UPDATE analysis SET $name='$value' WHERE analysis_id=$dbID";
	$self->prepare_execute($query);
}

1;

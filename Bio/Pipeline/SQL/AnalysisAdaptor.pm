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
            created, parameters,node_group_id
    FROM    analysis 
    WHERE   analysis_id = ?});

  $sth->execute( $id );
  my ($analysis_id,$logic_name,$program,$program_version,$program_file,$data_monger_id,
      $db,$db_version,$db_file,$runnable,$gff_source,$gff_feature,$created,
      $parameters,$node_group_id) = $sth->fetchrow_array;

  if( ! defined $analysis_id) {
    return undef;
  }

  my $node_group = $self->db->get_NodeGroupAdaptor->fetch_by_dbID($node_group_id);
  

  my $query = " SELECT  ai.iohandler_id 
                FROM    analysis_iohandler ai
                WHERE   ai.analysis_id = $id";
                        
  $sth = $self->prepare($query);                  
  $sth->execute ();

  my @ioh;
  while (my ($ioid) = $sth->fetchrow_array){
      push @ioh, $self->db->get_IOHandlerAdaptor->fetch_by_dbID($ioid);
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
                                            -PARAMETERS     => $parameters,
                                            -DATA_MONGER_ID => $data_monger_id,
                                            -CREATED        => $created,
                                            -LOGIC_NAME     => $logic_name,
                                            -IOHANDLER      =>\@ioh,
                                            -NODE_GROUP     => $node_group,
                                            -IO_MAP         => \%iomap);


  return $anal;
}

=head2 fetch_next_analysis

  Title   : fetch_next_analysis
  Usage   : my $analysis = $adaptor->fetch_next_analysis
  Function: fetches the next analysis based on current analysis
  Returns : the next analysis based on rules, undef if not found
  Args    : L<Bio::Pipeline::Analysis>

=cut

sub fetch_next_analysis {
    my ($self,$anal) = @_;
    my @rules = $self->db->get_RuleAdaptor->fetch_all;
    foreach my $rule(@rules){
      if(defined ($rule->current) && $rule->current->dbID == $anal->dbID){
          return $self->db->get_AnalysisAdaptor->fetch_by_dbID($rule->next->dbID);
      }
    }
    return undef;
}


=head2 fetch_create_input_id_ioh

  Title   : fetch_create_input_id_ioh
  Usage   : my $analysis = $adaptor->fetch_create_input_id_ioh
  Function: fetches the input create method which retrieves an array of input ids for 
            the next analysis 
  Returns : throws exception when something goes wrong.
            undef if the id is not in the db.
  Args    : L<Bio::Pipeline::Analysis>

=cut

sub fetch_create_input_id_ioh{
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
		parameters = ?,
		runnable = ?,
		gff_source = ?,
		gff_feature = ? } );

	$sth->execute
	    ( $analysis->logic_name,
	      $analysis->db,
	      $analysis->db_version,
	      $analysis->db_file,
	      $analysis->program,
	      $analysis->program_version,
	      $analysis->program_file,
	      $analysis->parameters,
	      $analysis->runnable,
	      $analysis->gff_source,
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
                parameters = ?,
                runnable = ?,
                gff_source = ?,
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
              $analysis->parameters,
              $analysis->runnable,
              $analysis->gff_source,
              $analysis->gff_feature
              );
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
     my @ioh = @{$analysis->iohandler};

     foreach my $ioh (@ioh){
         my $sth = $self->prepare("INSERT INTO analysis_iohandler 
                                   SET analysis_id = ?,
                                       iohandler_id = ?");
         $sth->execute($analysis->dbID,$ioh->dbID);
     }
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

     #     if (defined ($new_input_handler)) {
         #   my $sth = $self->prepare( q{
             #            INSERT INTO IOHandler 
             #  SET
             #   analysis_id = ?,
             #   iohandler_id = ? } );
             # $sth->execute
             #( $analysis->dbID, $new_input_handler->dbID);
             #}

      return $analysis->dbID;
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

1;

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
            db,db_version,db_file,
            runnable,
            gff_source,gff_feature,
            created, parameters
    FROM    analysis 
    WHERE   analysis_id = ?});

  $sth->execute( $id );
  my ($analysis_id,$logic_name,$program,$program_version,$program_file,
      $db,$db_version,$db_file,$runnable,$gff_source,$gff_feature,$created,
      $parameters) = $sth->fetchrow_array;

  if( ! defined $analysis_id) {
    return undef;
  }

  my $query = " SELECT  io.iohandler_id 
                FROM    iohandler io, analysis_iohandler ai
                WHERE   ai.iohandler_id = io.iohandler_id 
                        and ai.analysis_id = $id
                        and io.type = 'OUTPUT'";
  $sth = $self->prepare($query);                  
  $sth->execute ();

  print STDERR $query."\n";

  my @results = @{$sth->fetchall_arrayref};

  print STDERR scalar(@results)."\n";

  $self->throw ("Analyses must have one and only one output handler. This analysis has ".scalar(@results)." output handlers")
  unless (scalar(@results)== 1);

  my $output_handler = $self->db->get_IOHandlerAdaptor->fetch_by_dbID($results[0][0]);

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
                                            -CREATED        => $created,
                                            -LOGIC_NAME     => $logic_name,
                                            -OUTPUT_HANDLER => $output_handler );


  return $anal;
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

  return $analysis->dbID
  if defined ($analysis->dbID);

  if( defined $analysis->created ) {
    my $sth = $self->prepare( q{
      INSERT INTO analysis
      SET created = ?,
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
      ( $analysis->created,
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
    $sth = $self->prepare( q{
      SELECT last_insert_id() ;
    } );
    $sth->execute;
    my $dbID = ($sth->fetchrow_array)[0];
    $analysis->dbID( $dbID );
  } else {
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

    $sth = $self->prepare( q{
      SELECT last_insert_id()
    } );
    $sth->execute;

    my $dbID = ($sth->fetchrow_array)[0];
    $analysis->dbID( $dbID );
    if( defined $dbID ) {
      $sth = $self->prepare( q{
        SELECT created
        FROM analysis
        WHERE analysis_id = ? } );
      $sth->execute( $dbID );
      $analysis->created( ($sth->fetchrow_array)[0] );
    }
  }
}
1;

# Perl module for Bio::Pipeline::SQL::StateInfoContainer
#
# Adapted from Arne Stabenau's EnsEMBL StateInfoContainer
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::StateInfoContainer

=head1 SYNOPSIS

  $infoContainer = $dbobj->get_StateInfoContainer;


=head1 DESCRIPTION

  Module which encapsulates state request for objects in the database.
  Starts of with a table InputIdAnalysis, providing which analysis was done to
  inputIds but every state information access should go via this object.

  Deliberatly NOT called an adaptor, as it does not serve obejcts.

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Pipeline::SQL::StateInfoContainer;

use Bio::Pipeline::SQL::AnalysisAdaptor;
use Bio::Root::RootI;
use vars qw(@ISA);
use strict;

@ISA = qw( Bio::Root::RootI );

sub new {
  my ($class, $dbobj) = @_;
  my $self = $class->SUPER::new();

  $self->db( $dbobj );
  return $self;
}

sub fetch_analysis_by_inputId {
  my ($self,$inputId) = @_;

  my @result;
  my @row;

  my $anaAd = $self->db->get_AnalysisAdaptor();

  my $sth = $self->prepare( q {
    SELECT analysisId
      FROM InputIdAnalysis
     WHERE inputId = ?
     } );
  $sth->execute( $inputId);

  while( my @row = $sth->fetchrow_array ) {
    my $analysis = $anaAd->fetch_by_dbID( $row[0] );
    if( defined $analysis ) {
      push( @result, $analysis );
    }
  }

  return @result;
}

sub store_inputId_analysis {
  my ( $self, $inputId, $analysis ) = @_;

  my $sth = $self->prepare( qq{
      INSERT INTO InputIdAnalysis (
	  inputId, analysisId, created)
	  values (
	  '$inputId',
	           ?,
		  now() )} );
  $sth->execute( $analysis->dbID );

}

sub list_inputId_by_analysis {
  my $self = shift;
  my $analysis = shift;
  my @result;
  my @row;

  my $sth = $self->prepare( q {
    SELECT inputId
      FROM InputIdAnalysis
     WHERE analysisId = ? } );
  $sth->execute( $analysis->dbID );

  while( @row = $sth->fetchrow_array ) {
    push( @result, $row[0] );
  }

  return @result;
}

sub list_inputId_created_by_analysis {
  my $self = shift;
  my $analysis = shift;
  my @result;
  my @row;

  my $sth = $self->prepare( q {
    SELECT inputId, unix_timestamp(created)
      FROM InputIdAnalysis
     WHERE analysisId = ? } );
  $sth->execute( $analysis->dbID );

  while( @row = $sth->fetchrow_array ) {
    push( @result, [$row[0], $row[1]] );
  }

  return @result;
}

sub list_inputId_by_start_count {
  my $self = shift;
  my ($start,$count) = @_;
  my @result;
  my @row;

  my $query = qq{
    SELECT inputId, count(*) as c
      FROM InputIdAnalysis
     GROUP by inputId
     ORDER by c };

  if( defined $start && defined $count ) {
    $query .= "LIMIT $start,$count";
  }
  my $sth = $self->prepare( $query );
  $sth->execute;

  while( @row = $sth->fetchrow_array ) {
    push( @result, [ $row[0], $row[1] ] );
  }

  return @result;
}

sub delete_inputId{
  my $self = shift;
  my ($inputId) = @_;

  my $sth = $self->prepare( qq{
    DELETE FROM InputIdAnalysis
    WHERE  inputId = ?
    } );
  $sth->execute($inputId);
}

sub delete_inputId {
  my $self = shift;
  my ($inputId) = shift;

  my $sth = $self->prepare( qq{
    DELETE FROM InputIdAnalysis
    WHERE  inputId = ?} );
  $sth->execute($inputId);
}

sub delete_inputId_analysis {
  my $self = shift;
  my ($inputId, $analysisId) = @_;

  my $sth = $self->prepare( qq{
    DELETE FROM InputIdAnalysis
    WHERE inputId    = ?
    AND   analysisId = ?} );
  $sth->execute($inputId, $analysisId);
}

sub db {
  my ( $self, $arg )  = @_;
  ( defined $arg ) &&
    ($self->{'_db'} = $arg);
  $self->{'_db'};
}

sub prepare {
  my ( $self, $query ) = @_;
  $self->db->prepare( $query );
}

sub deleteObj {
  my $self = shift;
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

sub create_tables {
  my $self = shift;
  my $sth;

  $sth = $self->prepare("drop table if exists InputIdAnalysis");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE InputIdAnalysis (
    input_id     varchar(40) not null,
    analysis_id  int not null,
    created      datetime not null,

    PRIMARY KEY (analysis_id, input_id, class),
    KEY input_id_created (input_id, created),
    KEY input_id_class   (input_id, class)
    );
  });
  $sth->execute();
}

1;

# Perl module for Bio::Pipeline::SQL::RuleAdaptor
#
# Creator: Arne Stabenau <stabenau@ebi.ac.uk>
# Date of creation: 10.09.2000
# Last modified : 10.09.2000 by Arne Stabenau
#
# Copyright EMBL-EBI 2000
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::SQL::RuleAdaptor

=head1 SYNOPSIS

  $jobAdaptor = $dbobj->getRuleAdaptor;
  $jobAdaptor = $jobobj->getRuleAdaptor;


=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class Rule.
  There should be just one per application and database connection.


=head1 CONTACT

    Contact Arne Stabenau on implemetation/design detail: stabenau@ebi.ac.uk
    Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Pipeline::SQL::RuleAdaptor;

use Bio::Pipeline::Rule;
use Bio::Root::Root;
use vars qw(@ISA);
use strict;


@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head2 store

  Title   : store
  Usage   : $self->store( $rule );
  Function: Stores a rule in db
            Sets adaptor and dbID in Rule
  Returns : -
  Args    : Bio::Pipeline::Rule

=cut

sub store {
  my ( $self, $rule ) = @_;
  my $sth = $self->prepare( q{
    INSERT INTO rule_goal
       SET analysis_id= ? } );
  $sth->execute( $rule->goalAnalysis->dbID );
  $sth = $self->prepare( q {
    SELECT last_insert_id() } );
  $sth->execute;
  my $dbID = ($sth->fetchrow_array)[0];
  my @literals = $rule->list_conditions;
  for my $literal ( @literals ) {
    $sth = $self->prepare( qq{
      INSERT INTO rule_conditions
         SET rule_id=$dbID,
             analysis_id='$literal' } );
    $sth->execute;
  }
  $rule->dbID( $dbID );
  $rule->adaptor( $self );
}

=head2 remove

  Title   : remove
  Usage   : $self->remove( $rule );
  Function: removes given object from database.
  Returns : -
  Args    : Bio::Pipeline::Rule which must be persistent.
            ( dbID set )

=cut

sub remove {
  my ( $self, $rule ) = @_;

  my $dbID = $rule->dbID;
  if( !defined $dbID ) {
    $self->throw( "RuleAdaptor->remove called with non persistent Rule" );
  }

  my $sth = $self->prepare( qq {
    DELETE FROM rule_goal
    WHERE rule_id = $dbID } );
  $sth->execute;
  $sth = $self->prepare( qq {
    DELETE FROM rule_conditions
     WHERE rule_id = $dbID } );
  $sth->execute;
}


=head2 fetch_all

  Title   : fetch_all
  Usage   : @rules = $self->fetch_all;
  Function: retrieves all rules from db;
  Returns : List of Bio::Pipeline::Rule
  Args    : -

=cut

sub fetch_all {
  my $self = shift;
  my $anaAdaptor = $self->db->get_AnalysisAdaptor;
  my %rules;
  my ( $analysis, $rule, $dbID );
  my @queryResult;

  my $sth = $self->prepare( q {
    SELECT rule_id,analysis_id
      FROM rule_goal } );
  $sth->execute;

  while( @queryResult = $sth->fetchrow_array ) {
    $analysis = $anaAdaptor->fetch_by_dbID( $queryResult[1] );
    $dbID = $queryResult[0];

    $rule = Bio::Pipeline::Rule->new
      ( '-dbid'    => $dbID,
	      '-goal'    => $analysis,
        '-adaptor' => $self );
    # print STDERR "Setting $dbID rule\n";
    $rules{$dbID} = $rule;
  }

  $sth= $self->prepare( q{
    SELECT rule_id, analysis_id
      FROM rule_conditions } );
  $sth->execute;

  while( @queryResult = $sth->fetchrow_array ) {
      # print STDERR "@queryResult\n";
      $rules{$queryResult[0]}->add_condition( $queryResult[1] );
  }
  # print STDERR "Found @{[scalar keys %rules]} rules\n";
  return values %rules;
}

=head2 fetch_by_dbID

  Title   : fetch_by_dbID
  Usage   : $self->fetch_by_dbID
  Function: Standard fetch used by linked to objects
  Returns : Bio::Pipeline::Rule
  Args    : - 

=cut

sub fetch_by_dbID {
  my $self = shift;
  my $dbID = shift;
  
  my $anaAdaptor = $self->db->get_AnalysisAdaptor;
  my ( $analysis, $rule );
  my $queryResult;

  my $sth = $self->prepare( q {
    SELECT rule_id,analysis_id
      FROM rule_goal 
      WHERE rule_id = ? } );
  $sth->execute( $dbID  );

  $queryResult = $sth->fetchrow_hashref;
  if( ! defined $queryResult ) {
    return undef;
  }
  
  $analysis = $anaAdaptor->fetch_by_dbID( $queryResult->{goal} );
      
  $rule = Bio::Pipeline::Rule->new
    ( '-dbid'    => $dbID,
      '-goal'    => $analysis,
      '-adaptor' => $self );

  $sth= $self->prepare( q{
    SELECT rule_id, analysis_id
      FROM rule_conditions 
      WHERE rule_id = ?} );
  $sth->execute( $dbID );
  
  while( $queryResult = $sth->fetchrow_hashref ) {
    $rule->add_condition( $queryResult->{condition} );
  }
  return $rule;
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

sub create_tables{
  my ($self) = @_;
  my $sth;

  $sth = $self->prepare("drop table if exists rule_goal");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE rule_goal (
    rule_id           int unsigned default 0 not null auto_increment,
    goal  int unsigned,

    PRIMARY KEY (rule_id)
    );
  });
  $sth->execute();

  $sth = $self->prepare("drop table if exists rule_conditions");
  $sth->execute();

  $sth = $self->prepare(qq{
    CREATE TABLE rule_conditions (
    rule_id            int not null,
    analysis_id varchar(40)
    );
  });
  $sth->execute();
}

1;

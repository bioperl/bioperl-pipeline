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

  if (defined ($rule->dbID)) {
    my $sth = $self->prepare( qq{
      INSERT INTO rule
         SET current = ?
             next= ?
             action= ? } );
    $sth->execute($rule->current->dbID, $rule->next->dbID, $rule->action);
  
   $sth = $self->prepare( q{
      SELECT last_insert_id()
     } );
   $sth->execute;

   my $dbID = ($sth->fetchrow_array)[0];
   $rule->dbID( $dbID );
  }
  else {
    my $sth = $self->prepare( qq{
      INSERT INTO rule
         SET rule_id= ?,
             current= ?,
             next= ?,
             action= ?} );
    $sth->execute($rule->dbID, $rule->current->dbID, $rule->next->dbID, $rule->action);
  }
  #$rule->adaptor( $self );
  return $rule->dbID;
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
    DELETE FROM rule
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
  my %rules;
  my ($rule );
  my @queryResult;

  my $sth = $self->prepare( q {
    SELECT rule_id, current, next, action
      FROM rule } );
  $sth->execute;

  while( @queryResult = $sth->fetchrow_array ) {
    $rule = Bio::Pipeline::Rule->new
      ( '-dbid'    => $queryResult[0],
        '-current' => $queryResult[1],
        '-next'    => $queryResult[2],
        '-action'  => $queryResult[3],
        '-adaptor' => $self );
    $rules{$queryResult[0]} = $rule;
  }

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
  
  my ( $rule );
  my $queryResult;

  my $sth = $self->prepare( q {
    SELECT rule_id
      FROM rule 
      WHERE rule_id = ? } );
  $sth->execute( $dbID  );

  $queryResult = $sth->fetchrow_hashref;
  if( ! defined $queryResult ) {
    return undef;
  }
      
  $rule = Bio::Pipeline::Rule->new
    ( '-dbid'    => $queryResult->{rule_id} ,
      '-current'    => $queryResult->{current} ,
      '-next'    => $queryResult->{next} ,
      '-action'  => $queryResult->{action} ,
      '-adaptor' => $self );

  return $rule;
}



1;

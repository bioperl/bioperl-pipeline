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
use Bio::Pipeline::Job;
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

  if (!defined ($rule->dbID)) {
    my $current_anal_id;
    if (defined $rule->current) {
      $current_anal_id = $rule->current->dbID;
    }
    my $next_anal_id;
    if (defined $rule->next) {
      $next_anal_id = $rule->next->dbID;
    }

    my $sth = $self->prepare( qq{
      INSERT INTO rule
         SET rule_group_id=?,
             current = ?,
             next= ?,
             action= ? } );
    $sth->execute($rule->rule_group_id,$current_anal_id, $next_anal_id, $rule->action);
  
   $sth = $self->prepare( q{
      SELECT last_insert_id()
     } );
   $sth->execute;

   my $dbID = ($sth->fetchrow_array)[0];
   $rule->dbID( $dbID );
  }
  else {
    my $current_anal_id;
    if (defined $rule->current) {
      $current_anal_id = $rule->current->dbID;
    }
    my $next_anal_id;
    if (defined $rule->next) {
      $next_anal_id = $rule->next->dbID;
    }
    my $sth = $self->prepare( qq{
      INSERT INTO rule
         SET rule_id= ?,
             current= ?,
             next= ?,
             action= ?} );
    $sth->execute($rule->dbID, $current_anal_id, $next_anal_id, $rule->action);
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
  my @rules;
  my $sth = $self->prepare( q {
    SELECT rule_id 
      FROM rule } );
  $sth->execute;

  while( my($queryResult) = $sth->fetchrow_array ) {
    my $rule = $self->fetch_by_dbID($queryResult);
    push @rules, $rule;
  }
  return @rules;
}

sub check_dependency_by_job{
    my ($self,$job,@rules ) = @_;
    foreach my $rule(@rules){
       if (defined($rule->current) && $rule->current->dbID == $job->analysis->dbID){
           my $action=$rule->action;
           if(($action eq 'UPDATE') ||($action eq 'WAITFORALL_AND_UPDATE')){
                return 1;
           }
       }
    }
    return 0;
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
    SELECT rule_id,rule_group_id,current,next,action
      FROM rule 
      WHERE rule_id = ? } );
  $sth->execute( $dbID  );

  $queryResult = $sth->fetchrow_hashref;
  if( ! defined $queryResult ) {
    return undef;
  }

  my $current;
  my $next; 
  if (defined ($queryResult->{current})) {
     $current = $self->db->get_AnalysisAdaptor->fetch_by_dbID($queryResult->{current});
  }
  if (defined ($queryResult->{next})) {
     $next = $self->db->get_AnalysisAdaptor->fetch_by_dbID($queryResult->{next});
  }

  $rule = Bio::Pipeline::Rule->new
    ( '-dbid'    => $queryResult->{rule_id} ,
      '-current'    => $current,
      '-rule_group_id'=>$queryResult->{rule_group_id},
      '-next'    => $next ,
      '-action'  => $queryResult->{action} ,
      '-adaptor' => $self );
      
  return $rule;
}


=head2 fetch_rule_group_id

  Title   : fetch_rule_group_id
  Usage   : $self->fetch_rule_group_id($analysis_id,$rule_group_id)
  Function: fetch the rule group id based on the current analysis column id. If rule_group_id is
            provided, find the rule group of the analysis id NOT in the rule group. This
            is to look for analysis that are in the next rule group.
  Returns : Bio::Pipeline::Rule
  Args    : -analysis id 
            -rule_group_id

=cut

sub fetch_rule_group_id {
  my ($self,$current_analysis_id,$rule_group_id) = @_;
  if($rule_group_id){
    my $sth = $self->prepare("SELECT rule_group_id FROM rule 
                            WHERE current =? AND rule_group_id!=?");
    $sth->execute($current_analysis_id,$rule_group_id);
    my ($rule_grp_id) = $sth->fetchrow_array();
    return $rule_grp_id;
   }
    else {
      my $sth = $self->prepare("SELECT rule_group_id FROM rule 
                            WHERE current =?"); 
      $sth->execute($current_analysis_id);
      my ($rule_grp_id) = $sth->fetchrow_array();
      return $rule_grp_id;
    }
    
}

=head2 fetch_next_analysis_rule_group_id

  Title   : fetch_next_analysis_rule_group_id
  Usage   : $self->fetch_next_analysis_rule_group_id($analysis_id,$rule_group_id)
  Function: fetch the rule group id based on the next analysis column id. If rule_group_id is
            provided, find the rule group of the analysis id NOT in the rule group. This
            is to look for analysis that are in the next rule group.
  Returns : Bio::Pipeline::Rule
  Args    : -analysis id 
            -rule_group_id

=cut

sub fetch_next_analysis_rule_group_id {
  my ($self,$next_analysis_id,$rule_group_id) = @_;
  if($rule_group_id){
    my $sth = $self->prepare("SELECT rule_group_id FROM rule 
                            WHERE next =? AND rule_group_id!=?");
    $sth->execute($next_analysis_id,$rule_group_id);
    my ($rule_grp_id) = $sth->fetchrow_array();
    return $rule_grp_id;
   }
    else {
      my $sth = $self->prepare("SELECT rule_group_id FROM rule 
                            WHERE next=?");
      $sth->execute($next_analysis_id);
      my ($rule_grp_id) = $sth->fetchrow_array();
      return $rule_grp_id;
    }

}
1;

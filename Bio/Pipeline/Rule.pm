# Perl module for Bio::Pipeline::Rule
#
# Creator: Shawn Hoon <shawnh@fugu-sg.org>
# Date of creation: 04.04.2002 
# Last modified : 04.04.2002 by Shawn Hoon
#
# 
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Pipeline::Rule

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Pipeline::Rule;
use vars qw(@ISA);
use Bio::Root::RootI;
use strict;


@ISA = qw( Bio::Root::RootI );

=head2 Constructor

  Title   : new
  Usage   : ...Rule->new($analysis);
  Function: Constructor for Rule object
  Returns : Bio::Pipeline::Rule
  Args    : A Bio::Analysis object. Conditions are added later,
            adaptor and dbid only used from the adaptor.

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ( $goal, $adaptor, $dbID ) =
    $self->_rearrange( [ qw ( GOAL
                  			      ADAPTOR
                  			      DBID
            			     ) ], @args );
  $self->throw( "Wrong parameter" ) unless
    $goal->isa( "Bio::Pipeline::Analysis" );
  $self->dbID( $dbID );
  $self->goalAnalysis( $goal );
  $self->adaptor( $adaptor );
				
  return $self;
}

=head2 condition

  Title   : condition
  Usage   : $self->conditon(analysis->dbID);
  Function: Add/Set method for condition for the rule.
  Returns : nothing
  Args    : the dbID of an analysis that must have been fulfilled as a pre-requisite 
            for this next analysis.

=cut


sub condition {
  my $self = shift;
  my $condition = shift;

  if (defined $condition){
    $self->{'_condition'}= $condition;
  }    

  return $self->{'_condition'};
}


=head2 goalAnalysis

  Title   : goalAnalysis
  Usage   : $self->goalAnalysis($anal);
  Function: Get/set method for the goal analysis object of this rule.
  Returns : Bio::Analysis
  Args    : Bio::Analysis

=cut

sub goalAnalysis {
  my ($self,$arg) = @_;

  ( defined $arg ) &&
    ( $self->{'_goal'} = $arg );
  $self->{'_goal'};
}


# return 0 if nothing can be done or $goalAnalysis,
# if it should be done.

sub check_for_analysis {
  my $self = shift;
  my @analist = @_;
  my %anaHash;

  # reimplement with proper identity check!
  my $goal = $self->goalAnalysis->dbID;

  # print STDERR "My goal is " . $goal . "\n";

  for my $analysis ( @analist ) {
      # print STDERR " Analysis " . $analysis->logic_name . " " . $analysis->dbID . "\n";
    $anaHash{$analysis->logic_name} = $analysis;
    if( $goal == $analysis->dbID ) {
      # already done
      return 0;
    }
  }

  for my $cond ( $self->list_conditions ) {
    if( ! defined $anaHash{$cond} ) {
      return 0;
    }
  }
  return $self->goalAnalysis;
}





sub dbID {
  my ( $self, $dbID ) = @_;
  ( defined $dbID ) &&
    ( $self->{'_dbID'} = $dbID );
  $self->{'_dbID'};
}

sub adaptor {
  my ( $self, $adaptor ) = @_;
  ( defined $adaptor ) &&
    ( $self->{'_adaptor'} = $adaptor );
  $self->{'_adaptor'};
}

1;

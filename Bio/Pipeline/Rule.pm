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
use Bio::Root::Root;
use strict;


@ISA = qw( Bio::Root::Root );

=head2 Constructor

  Title   : new
  Usage   : ...
  Function: Constructor for Rule object
  Returns : Bio::Pipeline::Rule
  Args    : A Bio::Analysis object. Conditions are added later,
            adaptor and dbid only used from the adaptor.

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ( $current, $next, $action, $adaptor, $dbID ) =
    $self->_rearrange( [ qw (CURRENT
                             NEXT 
                             ACTION
                  	     ADAPTOR
                             DBID
            	            ) ], @args );
  $self->dbID( $dbID );
  $self->current( $current );
  $self->next( $next );
  $self->action( $action );
  $self->adaptor( $adaptor );
				
  return $self;
}

=head2 current


  Usage   : $self->current(analysis->dbID);
  Function: Add/Set method for condition for the rule.
  Returns : nothing
  Args    : the dbID of an analysis that must have been fulfilled as a pre-requisite 
            for this next analysis.

=cut


sub current {
  my $self = shift;
  my $current = shift;

  if (defined $current){
    $self->{'_current'}= $current;
  }    

  return $self->{'_current'};
}

=head2 next


  Usage   : $self->next(analysis->dbID);
  Function: Add/Set method for condition for the rule.
  Returns : nothing
  Args    : the dbID of an analysis that needs to be started after finishing the current analysis 

=cut


sub next {
  my $self = shift;
  my $next = shift;

  if (defined $next){
    $self->{'_next'}= $next;
  }

  return $self->{'_next'};
}

sub action {
  my $self = shift;
  my $action = shift;

  if (defined $action){
    $self->{'_action'}= $action;
  }

  return $self->{'_action'};
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

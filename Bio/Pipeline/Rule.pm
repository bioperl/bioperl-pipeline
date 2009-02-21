#
# BioPerl module for Bio::Pipeline::Rule
#
# Based on Ensembl pipeline module Bio::EnsEMBL::Pipeline::Rule
# originally written by Arne Stabenau <stabenau@ebi.ac.uk>
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Fugu Informatics Team <fuguteam@fugu-sg.org>
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Rule

=head1 SYNOPSIS

  use Bio::Pipeline::Rule

   my $rule = Bio::Pipeline::Rule->new ( '-dbid'    => 1,
                                         '-current' => 1, 
                                         '-next'    => 2,
                                         '-action'  => 'NOTHING');

=head1 DESCRIPTION

This object represents the conditional logic for workflow in the
pipeline.  Each Rule dictates for a given analysis what the next
analysis will be.  It also specifies any action to be taken before
going to the next job.  Usually this involves setting up of inputs for
the next analysis.

Each job runs a certain analysis on a specfic input.  When the job
finishes, it looks up the rule for its analysis (current) and see what
the next analysis to do will be. If there is one, depending on what
the action will be, it will create the next job with the same input
but for the next analysis.

  $job->current

the analysis dbID for the current analysis

  $job->next 

the analysis dbID for the next analysis

  $job->action

Specifies the preprocessing to be doing before next
analysis is to be carried out.

  Action
  -------------------------
  COPY_ID        copy the input id from the current 
                 analysis for the next analysis 
                 the new iohandler for the input is looked up
                 in the iohandler_map table
  NOTHING        Do nothing, tells the job to go quietly
  COPY_INPUT     copy this input means to copy the input_id along
                 with the iohandler for the input
  WAITFORALL     Wait for all jobs of this analysis to finish before
                 executing the rule.



=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
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
  http://bugzilla.open-bio.org/

=head1 AUTHOR

Based on Ensembl pipeline module Bio::EnsEMBL::Pipeline::Rule
originally written by Arne Stabenau, stabenau@ebi.ac.uk

# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by Fugu Informatics Team, fuguteam@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

# Let the code begin...


package Bio::Pipeline::Rule;
use vars qw(@ISA);
use Bio::Root::Root;
use strict;


@ISA = qw( Bio::Root::Root );

=head2 new 

  Title   : new
  Usage   :  my $rule = Bio::Pipeline::Rule->new ( '-dbid'    => 1,
                                         '-rule_group_id'=>1
                                         '-current' => 1,
                                         '-next'    => 2,
                                         '-action'  => 'NOTHING');
  Function: Constructor for Rule object
  Returns : L<Bio::Pipeline::Rule>
  Args    : -dbid     its dbID
            -rule_group_id the rule group that the rule belongs to
            -current  the current analysis dbID
            -next     the next analysis dbID
            -action   what to do for the next analysis

=cut


sub new {
  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);

  my ( $rule_group_id,$current, $next, $action, $adaptor, $dbID ) =
    $self->_rearrange( [ qw (RULE_GROUP_ID
                             CURRENT
                             NEXT 
                             ACTION
                      	     ADAPTOR
                             DBID
            	            ) ], @args );
  $self->rule_group_id($rule_group_id);
  $self->dbID( $dbID );
  $self->current( $current );
  $self->next( $next );
  $self->action( $action );
  $self->adaptor( $adaptor );
				
  return $self;
}

=head2 current

  Title   : current 
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

  Title   : next 
  Usage   : $self->next(analysis->dbID);
  Function: Add/Set method for condition for the rule.
  Returns : string 
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

=head2 action

  Title   : action 
  Usage   : $self->action('NOTHING')
  Function: get/set the rule action 
  Returns : string 
  Args    : NOTHING|COPY_ID|COPY_INPUT|WAITFORALL 

=cut

sub action {
  my $self = shift;
  my $action = shift;

  if (defined $action){
    $self->{'_action'}= $action;
  }

  return $self->{'_action'};
}

=head2 rule_group_id

  Title   : rule_group_id
  Usage   : $self->rule_group_id(1)
  Function: get/set the rule_group_id 
  Returns : integer 
  Args    : integer 

=cut

sub rule_group_id {
  my $self = shift;
  my $rule_group_id = shift;

  if (defined $rule_group_id){
    $self->{'_rule_group_id'}= $rule_group_id;
  }

  return $self->{'_rule_group_id'};
}

=head2 dbID

  Title   : dbID
  Usage   : $self->dbID(1)
  Function: get/set the rule dbID 
  Returns : string
  Args    : integer 

=cut

sub dbID {
  my ( $self, $dbID ) = @_;
  ( defined $dbID ) &&
    ( $self->{'_dbID'} = $dbID );
  $self->{'_dbID'};
}


=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor($adaptor)
  Function: get/set for the Rule Adaptor object 
  Returns : L<Bio::Pipeline::SQL::RuleAdaptor 
  Args    :  

=cut

sub adaptor {
  my ( $self, $adaptor ) = @_;
  ( defined $adaptor ) &&
    ( $self->{'_adaptor'} = $adaptor );
  $self->{'_adaptor'};
}

1;

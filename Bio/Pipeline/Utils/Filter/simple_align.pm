#
# BioPerl module for Bio::Pipeline::Utils::Filter::feature_filter
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Utils::Filter::feature_coverage - A simple filter that
filters a list of objects, according to one of it's attributes

=head1 SYNOPSIS

  # to filter a list of HSPs according to evalue,
  my $fc = Bio::Pipeline::Utils::Filter::feature_filter->
     new(-threshold=>0.001,
         -condition => '<',
         -tag => 'evalue');
  my $filtered = $fc->run(\@hsps);

=head1 DESCRIPTION

A generic filter for filtering of objects according to one of it's
attributest/tags.

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

=head1 AUTHOR - Jerm 

Email jerm@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Utils::Filter::simple_align;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Utils::Filter;
use Bio::Pipeline::DataType;
use Bio::SeqFeature::Generic;

@ISA = qw(Bio::Pipeline::Utils::Filter);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($remove_col) = $self->_rearrange([qw(REMOVE_COLUMNS)],@args);

    $remove_col && $self->remove_columns($remove_col);
}

=head2 remove_columns

  Title   : remove_columns 
  Usage   : $self->remove_columns();
  Function: Get set method for criteria the remove_columns to filter by.
            Currently accepts 'match'|'weak'|'stron'|'mismatch'|'gap'
  Returns : criteria as an array ref
  Args    : criteria as an array ref

=cut

sub remove_columns{
  my ($self,$remove_columns) = @_;

  if($remove_columns){
    $self->{'_remove_columns'} = $remove_columns;
  }
  return $self->{'_remove_columns'};
}

=head2 run 

  Title   : run 
  Usage   : $self->run($input)
  Function: run the filter 
  Returns : the hash reference of filtered objects.
  Args    : A hash reference of inputs objects 

=cut

sub run {
    my ($self,$input) = @_;
  	my @output;
    
   my @input =  ref($input) eq "ARRAY" ? @{$input} : ($input);
	foreach my $ele (@input){
    $ele->isa("Bio::SimpleAlign") || $self->throw("Only work with Bio::SimpleAlign objects");
    push @output, $ele->remove_columns([$self->remove_columns]);
	}
  return \@output;
}


1;
    




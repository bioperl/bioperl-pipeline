#
# BioPerl module for Bio::Pipeline::Utils::Filter::feature_filter
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Utils::Filter::feature_coverage

=head1 SYNOPSIS

  A simple filter that filters a list of objects, according to one of it's attributes.

  For example, to filter a list of HSPs according to evalue,
  
  my $fc = Bio::Pipeline::Utils::Filter::feature_filter->new(-threshold=>0.001,
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

package Bio::Pipeline::Utils::Filter::feature_filter;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Utils::Filter;
use Bio::Pipeline::DataType;
use Bio::SeqFeature::Generic;

@ISA = qw(Bio::Pipeline::Utils::Filter);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($threshold,$condition,$tag) = $self->_rearrange([qw(THRESHOLD CONDITION TAG)],@args);

    $threshold && $self->threshold($threshold);
	$condition && $self->condition($condition);
	$tag && $self->tag($tag);
}

=head2 condition

  Title   : condition 
  Usage   : $self->condition();
  Function: Get set method for the condition to filter by.
            Currently accepts = > >= < <= 
  Returns : condition as a string
  Args    : condition as a string

=cut

sub condition{
  my ($self,$condition) = @_;

  if($condition){
    $self->{'_condition'} = $condition;
  }
  return $self->{'_condition'};
}

=head2 tag

  Title   : tag
  Usage   : $self->tag();
  Function: get set for feature tag to filter by
  Returns :
  Args    :

=cut

sub tag{
  my ($self,$tag) = @_;

  if($tag){
    $self->{'_tag'} = $tag;
  }
  return $self->{'_tag'};
}

=head2 in_datatype 

  Title   : in_datatype 
  Usage   : $self->in_datatype()
  Function: returns the input datatype expected, for this filter, it can be anything
  Returns : L<Bio::Pipeline::Datatype>
  Args    : None

=cut

sub in_datatype {
  my($self) = @_;
  return Bio::Pipeline::DataType->new(-object_type=>"general",-reftype=>"array");
}

=head2 out_datatype 

  Title   : out_datatype 
  Usage   : $self->out_datatype()
  Function: returns the output datatype expected, for this filter, it can be anything
  Returns : L<Bio::Pipeline::Datatype>
  Args    : None

=cut

sub out_datatype {
  my($self) = @_;
  return Bio::Pipeline::DataType->new(-object_type=>"general",-reftype=>"array");
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
	my $tag = $self->tag;

    (ref($input) eq "ARRAY") || $self->throw("Expecting a array reference");

	foreach my $ele (@{$input}){
		if ($ele->can($tag)){
			push (@output,$ele) if ($self->_test_condition($ele->$tag));	
		}elsif ($ele->can('get_tag_values') && $ele->has_tag($tag)){
				push (@output,$ele) if ($self->_test_condition(${$ele->get_tag_values($tag)}));	
		}else{
			$self->throw("Trying to filter SeqFeature by tag ".$tag.
						" but that tag doesn't exist");
		
		}
	}
      
    return \@output;
}

sub _test_condition {
	my ($self,$value) = @_;

	if ($self->condition eq '='){
		return 1 if (($value == $self->threshold) || ($value eq $self->threshold));
	}elsif ($self->condition eq '>='){
		return 1 if ($value >= $self->threshold);
	}elsif ($self->condition eq '<='){
		return 1 if ($value <= $self->threshold);
	}elsif ($self->condition eq '<'){
		return 1 if ($value < $self->threshold);
	}elsif ($self->condition eq '>'){
		return 1 if ($value > $self->threshold);
	}else{
		$self->warn("Don't know what to do with this condition ".$self->condition);
	}
}

1;
    




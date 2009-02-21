#
# BioPerl module for Bio::Pipeline::Filter::feature_coverage
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::Filter::feature_coverage

=head1 SYNOPSIS

  my $fc = Bio::Pipeline::Filter::feature_coverage->new(-threshold=>80);
  my @filtered = $fc->run(@inputs);

=head1 DESCRIPTION

Specific filter for filtering of blast hits based on feature coverage.
Current use case for filtering the blast hits to be passed to genewise
for gene building. We only want the maximum coverage for a hit so as
to build the longest possible gene.

Also allow for number of overlapping similarity features as a parameter.

Logic adapted from module written previously by Jer-Ming Chia

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

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...

package Bio::Pipeline::Utils::Filter::feature_coverage;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Utils::Filter;
use Bio::Pipeline::DataType;
use Bio::SeqFeature::Generic;

@ISA = qw(Bio::Pipeline::Utils::Filter);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($evalue,$threshold,$cluster_size) = $self->_rearrange([qw(EVALUE THRESHOLD CLUSTER_SIZE)],@args);
    $threshold||=85; 
    $self->threshold($threshold);
    $self->cluster_size($cluster_size) if $cluster_size;
    $evalue && $self->evalue($evalue);
}

sub cluster_size {
  my ($self,$val) = @_;
  if($val){
    $self->{'_cluster_size'} = $val;
  }
  return $self->{'_cluster_size'};
}

sub evalue {
  my ($self,$val) = @_;
  if($val){
    $self->{'_evalue'} = $val;
  }
  return $self->{'_evalue'};
}

sub _group_to_hits {
  my ($self,@hsps) = @_;
  my %hash;
  foreach my $hsp (@hsps){
    if (!$hash{$hsp->hseqname}){
      my $hit = Bio::SeqFeature::Generic->new();
      $hit->add_sub_SeqFeature($hsp,'EXPAND');
      $hit->strand($hsp->strand);
      $hash{$hsp->hseqname} = $hit;
    }
    else {
      $hash{$hsp->hseqname}->add_sub_SeqFeature($hsp,'EXPAND');
    }
  }
  return values %hash;
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

    (ref($input) eq "ARRAY") || $self->throw("Expecting an array reference");
    my @hits = $self->_group_to_hits(@$input);

    return $self->_select_hits(@hits);

}

=head2 _set_coverage 

  Title   : _set_coverage 
  Usage   : $self->_set_coverage(@hits)
  Function: run the filter
  Returns : the hash reference of filtered objects.
  Args    : A hash reference of inputs objects

=cut

sub _set_coverage {
    my ($self,@hits) = @_;
    my @modified;
    foreach my $hit(@hits){
        foreach my $feat($hit->sub_SeqFeature){
          $hit->{'_sub_seqfeature_coverage'} += $feat->length;
        }
        push @modified, $hit;
    }
    return @modified;
}

=head2 _select_hits

  Title   : _select_hits
  Usage   : $self->_select_hits(@hits)
  Function: obtain the best scoring HSP within a certain area
  Returns : Array of hits  
  Args    : Array of hits

=cut

sub _select_hits{

  my ($self,@hits) = @_;
  my $initial = $#hits+1; 
  return unless $#hits >=0; 
  @hits = $self->_set_coverage(@hits);

  @hits= sort { $a->strand <=> $b->strand
                    ||
                 $a->start <=> $b->start } @hits;
 
  my @clusters; 


#Group the hits together based on overlap to generate clusters

  #add the first cluster
  my $prev = shift @hits;
  my $hit_cluster = Bio::SeqFeature::Generic->new() ;
  $hit_cluster->strand($prev->strand);
  $hit_cluster->add_sub_SeqFeature($prev,'EXPAND');
  $hit_cluster->{'_sub_seqfeature_coverage'} += $prev->length;
  push (@clusters,$hit_cluster);


  foreach my $hit(@hits){
      if ($hit->overlaps($hit_cluster,'strong')){
          my ($a_unique,$common,$b_unique) = $hit->overlap_extent($hit_cluster);
          $hit_cluster->add_sub_SeqFeature($hit,'EXPAND');
          $hit_cluster->{'_sub_seqfeature_coverage'} += $a_unique;
      }
      else{
          $hit_cluster = Bio::SeqFeature::Generic->new();
          $hit_cluster->{'_sub_seqfeature_coverage'} += $hit->{'_sub_seqfeature_coverage'};
          $hit_cluster->add_sub_SeqFeature($hit,'EXPAND');
          $hit_cluster->strand($hit->strand);
          push (@clusters,$hit_cluster);
       }
  }

  #prune clusters by number of members
 if($self->cluster_size){
  my @new_clusters ;
  foreach my $c(@clusters){
    my $size = scalar($c->sub_SeqFeature);
    next if $self->cluster_size> $size;
    push @new_clusters, $c;
  }
  @clusters = @new_clusters;
 }

#Prune the features of each cluster to only include those that gives added coverage

  my @selected_hits;

  foreach my $cluster (@clusters){

      my $new_cluster = Bio::SeqFeature::Generic->new() ;

      my @hits = $cluster->sub_SeqFeature;

      @hits = sort { $b->{'_sub_seqfeature_coverage'}<=> $a->{'_sub_seqfeature_coverage'}} @hits;

      my $longest_hit = shift @hits;

      push (@selected_hits,$longest_hit);

#search other hits against longest hit
HSP:  foreach my $hit (@hits){
        my $overlap =0;
        my $missing_exon =0;

HSP_HIT: foreach my $hsp_hit ($hit->sub_SeqFeature){
          my $hit_flag =0;

LONG:       foreach my $longest_hit ($longest_hit->sub_SeqFeature){
              if ($hsp_hit->overlaps($longest_hit)){
                $hit_flag =1;
                my ($overlap_start,$overlap_end);
                $overlap_start = ($longest_hit->start < $hsp_hit->start) ? $hsp_hit->start : $longest_hit->start;
                $overlap_end = ($longest_hit->end > $hsp_hit->end) ? $hit->end : $longest_hit->end;
                $overlap += $overlap_end - $overlap_start;
              }
            }
            $missing_exon = 1 unless ($hit_flag);
         }

        if (($overlap == 0 ) || (($missing_exon)&&( int($hit->{'_sub_seqfeature_coverage'}/$longest_hit->{'_sub_seqfeature_coverage'} * 100) >= $self->threshold))){
            $new_cluster->{'_sub_seqfeature_coverage'} += $hit->length;
            $hit->{'_sub_seqfeature_coverage'} = $hit->{'_sub_seqfeature_coverage'};
            $new_cluster->add_sub_SeqFeature($hit,'EXPAND');
            $new_cluster->strand($hit->strand);
        }

      }
      push (@clusters,$new_cluster) unless (scalar($new_cluster->sub_SeqFeature) == 0);
  }

  return \@selected_hits;
}

1;
    




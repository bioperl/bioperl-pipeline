package Bio::Pipeline::Filter::feature_coverage;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::Filter;
use Bio::Pipeline::DataType;
use Bio::SeqFeature::Generic;

@ISA = qw(Bio::Pipeline::Filter);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($threshold) = $self->_rearrange([qw(THRESHOLD)],@args);

    $threshold && $self->threshold($threshold);
}

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqFeatureI',
                                          '-name'=>'sequence',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

sub run {
    my ($self,@output) = @_;

    #dummy for now, just return sub set. to be replaced with jerm's filter logic
    $#output > 0 || return;

    return $self->_select_hits(@output);
}

=head2 _select_features

  Title   : _select_features
  Usage   : $self->_select_features(@features)
  Function: obtain the best scoring HSP within a certain area
  Returns : Array of FeaturePairs
  Args    : Array of selected hseqnames

=cut

sub _select_hits{

  my ($self,@hits) = @_;

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
          $hit_cluster->add_sub_SeqFeature($hit,'EXPAND');
          $hit_cluster->{'_sub_seqfeature_coverage'} += $hit->length;
          $hit->{'_sub_seqfeature_coverage'} = $hit_cluster->{'_sub_seqfeature_coverage'};

      }
      else{
          $hit_cluster = Bio::SeqFeature::Generic->new();
          $hit_cluster->{'_sub_seqfeature_coverage'} += $hit->length;
          $hit->{'_sub_seqfeature_coverage'} = $hit_cluster->{'_sub_seqfeature_coverage'};
          $hit_cluster->add_sub_SeqFeature($hit,'EXPAND');
          $hit_cluster->strand($hit->strand);

          push (@clusters,$hit_cluster);
       }
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

  my @features;

  return @selected_hits;
}

1;
    




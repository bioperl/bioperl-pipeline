# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
# =pod
#
# =head1 NAME
#
# Bio::Pipeline::Runnable::RepeatMasker
#
=head1 SYNOPSIS


=head1 DESCRIPTION

EnsemblFamily Runnable that takes in Bio::Cluster::Family and stores it
into a Ensembl Family schema.

=head1 CONTACT

shawnh@fugu-sg.org

=head1 APPENDIX

=cut

package Bio::Pipeline::Runnable::EnsemblFamily;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use Bio::EnsEMBL::ExternalData::Family::Taxon;
use Bio::DB::BioSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;



@ISA = qw(Bio::Pipeline::RunnableI);

=head2 new

  Title   :   new
  Usage   :   $self->new()
  Function:
  Returns :
  Args    :

=cut

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my @params = split(' ',$args[0]);
  my ($release,$bioperldb_loc,$ensembl_loc,$family_tag) = $self->_rearrange([qw(RELEASE BIOPERLDB_LOCATOR ENSEMBL_FAMILY_LOCATOR FAMILY_TAG)],@params);
  $release && $self->release($release);
  $bioperldb_loc && $self->bioperldb_locator($bioperldb_loc);
  $ensembl_loc && $self->ensembl_family_locator($ensembl_loc);
  $family_tag && $self->family_tag($family_tag);

  return $self;

}

=head2 datatypes

  Title   :   datatypes
  Usage   :   $self->datatypes()
  Function:   returns a hash of the datatypes required by the runnable
  Returns :
  Args    :

=cut

sub datatypes {
  my ($self) = @_;
  my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::Cluster::FamilyI',
                                        '-name'=>'sequence',
                                        '-reftype'=>'ARRAY');
  my %dts;
  #Replace seq1 with whatever you want to call your get/set methods
  $dts{family} = $dt;
  return %dts;

}

=head2 family

  Title   :   family 
  Usage   :   $self->family ()
  Function:   get/set for families 
  Returns :
  Args    : 

=cut

sub family {
  my ($self,$family) = @_;
  if($family){
    $self->{'_family'} = $family;
  }
  return $self->{'_family'};
}
sub family_tag {
  my ($self,$family_tag) = @_;
  if($family_tag){
    $self->{'_family_tag'} = $family_tag;
  }
  return $self->{'_family_tag'};
}
sub release {
  my ($self,$release) = @_;
  if($release){
    $self->{'_release'} = $release;
  }
  return $self->{'_release'};
}

sub bioperldb_locator{
    my ($self,$locator) = @_;
    if($locator){
        $self->{'_bioperldb_locator'} = $locator;
    }
    return $self->{'_bioperldb_locator'};
}

sub ensembl_family_locator{
    my ($self,$locator) = @_;
    if($locator){
        $self->{'_ensembl_locator'} = $locator;
    }
    return $self->{'_ensembl_locator'};
}


=head2 run

  Title   :   run
  Usage   :   $self->run()
  Function:   execute 
  Returns :   
  Args    :

=cut

sub run {
  my ($self) = @_;
  my $family = $self->family;
  my $ensembl_locator = $self->ensembl_family_locator;

  my $ens_db = Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor->new($self->_format_arg($ensembl_locator));
  my @ens_fam; 
  my $family_count = 1;;
  foreach my $fam (@{$family}){
      my @members = $fam->members;
      my @ens_mem;
      foreach my $mem (@members){
        my $taxon = $mem->species;
        bless $taxon,"Bio::EnsEMBL::ExternalData::Family::Taxon";

        my $member = Bio::EnsEMBL::ExternalData::Family::FamilyMember->new();
        $member->family_id($fam->family_id);
        my ($annot) = $mem->annotation->get_Annotations('dblink');
        $member->database($annot->database);
        $member->stable_id($mem->display_name);
        $ens_db->get_TaxonAdaptor->store_if_needed($taxon);
        $member->taxon_id($taxon->taxon_id);

        $member->adaptor($ens_db->get_FamilyMemberAdaptor);

        #HACK FOR NOW until generate description file with ensembl peps
        $member->database || $member->database('ensembl');
        push @ens_mem, $member;
      }
      my $tag = $self->family_tag;
      my $stable_id = sprintf ("$tag%011.0d",$family_count);
      $family_count++;
      my $ens_fam= new Bio::EnsEMBL::ExternalData::Family::Family(-stable_id=>$stable_id,
                                                                  -members=>\@ens_mem,  
                                                                  -description=>$fam->description,
                                                                  -score=>$fam->annotation_score,
                                                                  -adpator=>$ens_db->get_FamilyAdaptor);

      $ens_fam->release($self->release);
      #$ens_fam->annotation_confidence_score($fam->annotation_score);

      $ens_db->get_FamilyAdaptor->store($ens_fam);
#      push @ens_fam, $ens_fam;
  }

 # $self->output(\@ens_fam);

  return $self->output;

}

sub _format_arg {
    my ($self,$str) = @_;
    my @param = split(/;/,$str);
    my %hash;
    foreach my $param(@param){
        $param=~/(\S+?)=(\S*)/ || do { warn("In loading $str, could not split into keyvalue .Ignoring"); next; };
        my $key = $1;
        my $value = $2;
        $hash{"-$key"}=$value;
    }
    return %hash;
}

1;

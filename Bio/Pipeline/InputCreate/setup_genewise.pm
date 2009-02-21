#
# BioPerl module for Bio::Pipeline::InputCreate::setup_genewise
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Input::setup_genewise

=head1 SYNOPSIS

  my $inc = Bio::Pipeline::Input::setup_genewise->
      new(-slice_ioh=>$slice_ioh,
          -protein_ioh=>$pioh,
          -dh_ioh     =>$dh_ioh,
          -padding => 1000);
  $inc->run;

=head1 DESCRIPTION

This module setsup genewise jobs. It is really meant to work with
ensembl objects for it takes in DnaPepAlignFeatures, group them by the
hseqname and creates one genewise job per hit. Each job will consist
of two inputs, a target dna and a peptide query. The target dna is a
slice and its defined as the range of the peptide hit + padding on
either side.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate::setup_genewise;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($slice_ioh,$protein_ioh,$dh_name,$padding) = $self->_rearrange([qw(SLICE_IOH PROTEIN_IOH DYN_ARG_DATAHANDLER_NAME PADDING)],@args);

    $slice_ioh || $self->throw("Need an iohandler for the slice");
    $self->slice_ioh($slice_ioh);

    $protein_ioh || $self->throw("Need an iohandler for the protein");
    $self->protein_ioh($protein_ioh);

    $dh_name || $self->throw("Need an datahandler id for fetch_contig_start_end method");
    $self->dhid($dh_name);

    $padding = $padding || 1000;
    $self->padding($padding);

}

=head2 padding

  Title   : padding
  Usage   : $self->padding()
  Function: get/sets of the padding on each side of sequence 
            to pad before passing to genewise 
  Returns :  
  Args    :

=cut

sub padding{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_padding'} = $arg;
    }
    return $self->{'_padding'};
}


sub slice_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_slice_ioh'} = $arg;
    }
    return $self->{'_slice_ioh'};
}
sub genewise_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_genewise_ioh'} = $arg;
    }
    return $self->{'_genewise_ioh'};
}

=head2 protein_ioh

  Title   : protein_ioh
  Usage   : $self->protein_ioh()
  Function: get/set of the iohandler id for fetching the protein  sequence
  Returns :
  Args    :

=cut

sub protein_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_protein_ioh'} = $arg;
    }
    return $self->{'_protein_ioh'};
}

=head2 dhid

  Title   : dhid
  Usage   : $self->dhid()
  Function: get/set of the datahandler id for dynamic arguments
  Returns :
  Args    :

=cut

sub dhid {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_dhid'} = $arg;
    }
    return $self->{'_dhid'};
}

=head2 datatypes

  Title   : datatypes
  Usage   : $self->datatypes()
  Function: get/set of the datatypes required for this input create
  Returns :
  Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqFeatureI',
                                          '-name'=>'sequence',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

=head2 run

  Title   : run
  Usage   : $self->run($next_anal,$input)
  Function: creates the jobs for genewise 
  Returns :
  Args    : L<Bio::Pipeline::Analysis>, Hash reference

=cut

sub run {
    my ($self,$next_anal,$input) = @_;

    my $ioh = $self->dbadaptor->get_IOHandlerAdaptor->fetch_by_dbID($self->slice_ioh);
    my $dh_name = $self->dhid;
IOH:    foreach my $dh($ioh->datahandlers){
      if($dh->method eq $dh_name){
        $self->dhid($dh->dbID);
         last IOH;
      }
    }
    my @gw_ioh = @{$next_anal->iohandler};

    (ref($input) eq "HASH") || $self->throw("Expecting a hash reference");
    keys %{$input} > 1 ? $self->throw("Expecting only one entry for setup_genewise"):{};

    my ($key) = keys %{$input};
    my @hits= ref ($input->{$key}) eq 'ARRAY' ?  @{$input->{$key}} : $input->{$key};
    my %hash;

    #group the hsps by hit seqname (one gw job per hit)
    #foreach my $hsp (@output){
     # push @{$hash{$hsp->hseqname}},$hsp;
    #}
 
    $#hits>= 0 || return;
    ref $hits[0] || return;
    $hits[0]->isa("Bio::SeqFeatureI") || $self->throw("Need a SeqFeatureI object to setup_genewise");
    my @hsps = $hits[0]->get_SeqFeatures; 
    my $chr_name = $hsps[0]->entire_seq->chr_name;
    my $chr_start = $hsps[0]->entire_seq->chr_start;
    my $slice_length = $hsps[0]->entire_seq->length;
    my $padding = $self->padding; 
    #shawn to fix--creating input for contig_start_end
    foreach my $hit(@hits){
        my @hsps = $hit->get_SeqFeatures;
        my $slice_start = $hit->start;
        if ($slice_start > $padding){
            $slice_start -= $padding;
        }
        else {
            $slice_start = 1;
        }
        my $slice_end   = $hit->end;
        if ($slice_end < ($slice_length - $padding)){
            $slice_end += $padding;
        }

       #offset to change to chromosomal coordinates
        $slice_start += $chr_start;
        $slice_end   += $chr_start;

        my $protein_id   = $hsps[0]->hseqname;
        my $strand       = $hsps[0]->strand;
        
        my $input1 = Bio::Pipeline::Input->new(-name=>$protein_id,-tag=>"query_pep",-input_handler=>$self->protein_ioh);
        my $strand = $hit->strand || 1;
        my $input3 = Bio::Pipeline::Input->new(-name=>$strand,-tag=>"genewise_strand");

        my @arg;
        my $arg = Bio::Pipeline::Argument->new(-rank=>1,-value=>$slice_start,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;
        $arg = Bio::Pipeline::Argument->new(-rank=>2,-value=>$slice_end,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;

        my $input2 = Bio::Pipeline::Input->new(-name=>$chr_name,-tag=>"target_dna",-input_handler=>$self->slice_ioh,-dynamic_arguments=>\@arg);
        my $job = $self->create_job($next_anal,[$input1,$input2,$input3]);
        $job->status('HOLD');

        $self->dbadaptor->get_JobAdaptor->store($job);
        
    }
        
    
}

1;
    




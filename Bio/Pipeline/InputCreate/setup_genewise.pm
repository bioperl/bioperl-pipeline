package Bio::Pipeline::InputCreate::setup_genewise;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($contig_ioh,$protein_ioh,$dh_ioh,$padding) = $self->_rearrange([qw(CONTIG_IOH PROTEIN_IOH DATA_HANDLER_ID PADDING)],@args);

    $contig_ioh || $self->throw("Need an iohandler for the contig");
    $self->contig_ioh($contig_ioh);

    $protein_ioh || $self->throw("Need an iohandler for the protein");
    $self->protein_ioh($protein_ioh);

    $dh_ioh || $self->throw("Need an datahandler id for fetch_contig_start_end method");
    $self->dhid($dh_ioh);

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

=head2 contig_ioh

  Title   : contig_ioh
  Usage   : $self->contig_ioh()
  Function: get/set of the iohandler id for fetching the contig sequence 
  Returns :
  Args    :

=cut

sub contig_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_contig_ioh'} = $arg;
    }
    return $self->{'_contig_ioh'};
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

=head2 contig_ioh

  Title   : contig_ioh
  Usage   : $self->contig_ioh()
  Function: get/set of the iohandler id for fetching the contig sequence
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

    (ref($input) eq "HASH") || $self->throw("Expecting a hash reference");
    keys %{$input} > 1 ? $self->throw("Expecting only one entry for setup_genewise"):{};

    my ($key) = keys %{$input};
    my @output = $input->{$key};
 
    #check the first is enuff?
    $#output >= 0 || return;
    $output[0]->isa("Bio::SeqFeatureI") || $self->throw("Need a SeqFeatureI object to setup_genewise");
    my @sub = $output[0]->sub_SeqFeature;
    my ($first_sub)= $sub[0];
    my $chr = $first_sub->entire_seq->db_handle->get_Contig($first_sub->entire_seq->display_id)->chromosome;
    my $contig_id = $first_sub->entire_seq->db_handle->get_Contig($first_sub->entire_seq->display_id)->internal_id;
    my ($chr_name,$chr_start,$chr_end) = $first_sub->entire_seq->db_handle->get_StaticGoldenPathAdaptor->get_chr_start_end_of_contig($first_sub->entire_seq->display_id);

    my $contig_length = $first_sub->entire_seq->length;
    my $padding = $self->padding; 
    #shawn to fix--creating input for contig_start_end
    foreach my $output(@output){
        my @sub = $output->sub_SeqFeature;
        my $contig_name  = $sub[0]->seqname;
        my $contig_start = $output->start;
        if ($contig_start > $padding){
            $contig_start -= $padding;
        }
        else {
            $contig_start = 1;
        }
        my $contig_end   = $output->end;
        if ($contig_end < ($contig_length - $padding)){
            $contig_end += $padding;
        }

       #offset to change to chromosomal coordinates
        $contig_start += $chr_start;
        $contig_end   += $chr_start;

        my $protein_id   = $sub[0]->hseqname;
        my $strand       = $output->strand;
        
        my $input1 = Bio::Pipeline::Input->new(-name=>$protein_id,-tag=>"query_pep",-input_handler=>$self->protein_ioh);

        my @arg;
        my $arg = Bio::Pipeline::Argument->new(-rank=>1,-value=>$chr,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;
        $arg = Bio::Pipeline::Argument->new(-rank=>2,-value=>$contig_start,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;
        $arg = Bio::Pipeline::Argument->new(-rank=>3,-value=>$contig_end,-dhid=>$self->dhid,-type=>"SCALAR");
        push @arg, $arg;

        my $cigar_line = "$strand,$contig_start-$contig_end"; 
        my $input2 = Bio::Pipeline::Input->new(-name=>$contig_name,-tag=>"target_dna",-input_handler=>$self->contig_ioh,-dynamic_arguments=>\@arg);
        my $input3 = Bio::Pipeline::Input->new(-name=>$cigar_line,-tag=> "cigar");
        my $input4 = Bio::Pipeline::Input->new(-name=>$contig_id,-tag=> "contig_id");


        my $job = $self->create_job($next_anal,[$input1,$input2,$input3,$input4]);

        $self->dbadaptor->get_JobAdaptor->store($job);
        
    }
        
    
}

1;
    




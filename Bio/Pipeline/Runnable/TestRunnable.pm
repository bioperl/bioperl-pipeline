#doesn't do anything. Used for testing pipeline
package Bio::Pipeline::Runnable::TestRunnable;

use vars qw(@ISA);
use strict;
use Bio::Pipeline::RunnableI;
use Bio::EnsEMBL::SeqFeature;
use Bio::SeqIO;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->{'_output'} = []; 
    return $self;
}
sub seq {
    my ($self,$value) = @_;
    if ($value){
        $self->{'_seq'} = $value;
    }
    return $self->{'_seq'};
}
sub datatypes {
    my ($self) = @_;

    my $dt = Bio::Pipeline::DataType->new(-object_type=>"Bio::PrimarySeqI",
                                          -name=>"sequence",
                                          -reftype=>"SCALAR");
    my %dt;
    $dt{set_seq} = $dt;
    return %dt;
}
sub set_seq {
    my ($self,$seq) = @_;
    $seq->isa("Bio::PrimarySeqI") || $self->throw("Bio::PrimarySeqI");
    $self->seq($seq);
}
sub run {
    my ($self) = @_;
    my $seq = $self->seq();
    $seq || $self->throw("Input seq not set!");
    print STDERR "Creating temp file for sequence\n";
    my $out = Bio::SeqIO->new(-file=>">seq",-format=>'FASTA');
    $out->write_seq($self->seq);

    print STDERR "Result file: /tmp/Results_test.tmp\n";
    $self->result("/tmp/Results_test.tmp");

    $self->run_analysis();   
    print STDERR "Parsing Results....\n";

    $self->parse_results();
}
sub analysis {
    my ($self,$value) = @_;
    
    if($value){
        $self->{'_analysis'} = $value;
    }
    return $self->{'_analysis'};
}
sub result {
    my ($self,$value) = @_;
    if($value){
        $self->{'_result'} = $value;
    }
    return $self->{'_result'};
}

sub run_analysis {
    my ($self) = @_;
    print STDERR "Pseudo Running ....\n\n\n";
    my $rfh = $self->result();
    open(FILE,">$rfh");
    
    print FILE "10\t20\t-1\n";
    close FILE;

}

sub parse_results {
    my ($self) = @_;
    my $rfh = $self->result();
    open (RESULTS,$rfh);
    my @feats;
    while (<RESULTS>){
        my $line = $_;
        my ($start,$end,$strand) = split("\t",$line);
        my $feat = new Bio::EnsEMBL::SeqFeature(-seqname=>'Scaffold_267_153',
                                                -start =>$start,
                                                -analysis=>$self->analysis,
                                                -end   =>$end,
                                                -score =>100,
                                                -source_tag=>"source_tag",
                                                -primary_tag=>"pri_tag",
                                                -strand =>$strand);
       push @feats, $feat;
    }
    $self->output(@feats);

}
sub output {
    my ($self,@feats) = @_;
    if (@feats){
       @{$self->{'_output'}} = @feats;
   }
   return @{$self->{'_output'}};
}
1;


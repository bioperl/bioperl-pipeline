#doesn't do anything. Used for testing pipeline
package Bio::Pipeline::Runnable::TestRunnable;

use vars qw(@ISA);
use strict;
use Bio::Pipeline::RunnableI;
use Bio::SeqFeature::Generic;
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
    $dt{seq} = $dt;
    return %dt;
}
sub run {
    my ($self) = @_;
    my $seq = $self->seq();
    $seq || $self->throw("Input seq not set!");
    my $rev = $seq->revcom;
    $self->output($rev);

#    $self->run_analysis();   
 #   print STDERR "Parsing Results....\n";

   # $self->parse_results();
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
        my $feat = new Bio::SeqFeature::Generic(-seqname=>'Scaffold_267_153',
                                                -start =>$start,
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
    my ($self,$seq) = @_;
    if ($seq){
       @{$self->{'_output'}} = $seq;
   }
   return @{$self->{'_output'}};
}
1;


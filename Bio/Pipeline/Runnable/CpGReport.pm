# Runnable for CpGReport which is available in EMBOSS
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Juguang Xiao <juguang@fugu-sg.org>
#
# You may distribute this module under the same terms as perl itself
#
# 

package Bio::Pipeline::Runnable::CpGReport;

use vars qw(@ISA);
use strict;
use Bio::Pipeline::RunnableI;
use Bio::Pipeline::DataType;
use Bio::Factory::EMBOSS;
use Bio::Root::IO;
use Bio::Tools::GFF;

@ISA = qw(Bio::Pipeline::RunnableI);

sub datatypes{
    my ($self) = @_;

    my $dt = Bio::Pipeline::DataType->new(
        -object_type => 'Bio::SeqI',
        -name => 'seqence',
        -reftype => 'ARRAY'
    );

    my %dts;
    $dts{seq} = $dt;
    return %dts;
}

sub seq{
    my ($self, $seq) = @_;
    if(defined($seq)){
        $self->{_seq} = $seq;
    }
    return $self->{_seq};
}

sub run{
    my ($self) = @_;

    my $factory = new Bio::Factory::EMBOSS;
    my $cpg = $factory->program('cpgreport');
    my $io = Bio::Root::IO->new();
    my $tmpdir = $io->tempdir(CLEANUP=>1);
    my ($tfh,$outfile) = $io->tempfile($tmpdir);

    my @params = ('-sequence'=>$seq,'-featout'=>$outfile);
    push @params, $self->parse_params($analysis->analysis_parameters,1);

    eval{ $cpg->run({@params});};

    $self->throw("CPG Runnable had problems running. $@") if $@;

    my $parser = Bio::Tools::GFF->new(-file => $outfile);
    my @features;
    while(my $f = $parser->next_feature){
        push @features, $f;
    }

    $self->output(\@features);
}

sub output{
    my ($self, $features) = @_;
    if(defined $features){
        (ref($features) eq 'ARRAY') || $self->throw("Output must be an array ref");
        $self->{'_features'} = $features;
    }

    return @{$self->{'_features'}};   
}

1;




package Bio::Pipeline::Control::AllAnalysisResponse;

use strict;
use vars qw(@ISA);
use Bio::Pipeline::Control::Response;
use Bio::Pipeline::Analysis;
use Bio::Pipeline::Control::Protocol;

@ISA = qw(Bio::Pipeline::Control::Response);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);

    my ($all_analysis) = $self->_rearrange([qw(ALL_ANALYSIS)], @args);
    $all_analysis && $self->all_analysis($all_analysis);

    return $self;
}

sub all_analysis {
    my ($self, $all_analysis) = @_;
    return $self->{_all_analysis} = $all_analysis if defined $all_analysis;
    return $self->{_all_analysis};
}

sub encode {
    my ($class, $response) = @_;
    if(ref($response) ne 'Bio::Pipeline::Control::AllAnalysisResponse'){
        $class->throw('[', ref($response), '] is not required type');
    }

    my $message = "[return_all_analysis]\n";
    foreach(@{$response->all_analysis}){
        $message .= $_->dbID ."\t". $_->logic_name ."\n";
    }
    $message .= "\/\/\n";
    return $message;
}

sub decode {
    my ($class, $message) = @_;
    my @lines = @{Bio::Pipeline::Control::Protocol->clear_lines($message)};
    my @all_analysis;
    my $firstline = shift @lines;
    if($firstline =~ /return_all_analysis/){
        $class->throw("\[$firstline\], wrong command type");
    }
    foreach(@lines){
        my ($dbID, $logic_name) = split;
        push @all_analysis, Bio::Pipeline::Analysis->new(
            -dbid => $dbID,
            -logic_name => $logic_name
        );
    }

    my $response = Bio::Pipeline::Control::AllAnalysisResponse->new(
        -title => 'return_all_analysis',
        -all_analysis => \@all_analysis
    );

    return $response;
}

1;
